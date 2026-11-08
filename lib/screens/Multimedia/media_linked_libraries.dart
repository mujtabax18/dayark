import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../family_tree/models/family_tree_models.dart';
import '../family_tree/services/family_tree_repository.dart';
import '../family_tree/view/family_tree_detail_screen.dart';
import '../family_tree/view/family_tree_home_screen.dart';
import '../family_tree/view/life_archive_media.dart';
import '../scanner/controllers/provideers/scanGroupRepoProvider.dart';
import '../scanner/data/models/ScanGroupPreview.dart';
import '../scanner/data/repo/scan_group_service.dart';
import '../scanner/view/ScanGroupViewScreen.dart';
import '../scanner/view/scanner_gallery_screen.dart';

/// A read-only index of content already owned by Life Archive and Scanner.
/// Neither media files nor database rows are duplicated into Media Studio.
class LinkedMemoryAlbum {
  const LinkedMemoryAlbum(this.archive, this.memory);
  final FamilyTree archive;
  final FamilyMemory memory;
}

class MediaLinkedOverview {
  const MediaLinkedOverview({
    required this.albums,
    required this.documents,
  });
  final List<LinkedMemoryAlbum> albums;
  final List<ScanGroupPreview> documents;
}

class MediaLinkedLibrariesService {
  MediaLinkedLibrariesService(this._scanGroups);
  final ScanGroupService _scanGroups;
  final FamilyTreeRepository _archives = FamilyTreeRepository();

  Future<MediaLinkedOverview> load() async {
    final archives = await _archives.getTrees();
    final results = await Future.wait(
      archives.map((archive) async =>
          (archive: archive, memories: await _archives.getMemories(archive.id))),
    );
    final albums = <LinkedMemoryAlbum>[
      for (final group in results)
        for (final memory in group.memories)
          LinkedMemoryAlbum(group.archive, memory),
    ]..sort((a, b) => (b.memory.memoryDate ?? b.memory.createdAt)
        .compareTo(a.memory.memoryDate ?? a.memory.createdAt));
    final documents = <ScanGroupPreview>[...await _scanGroups.fetchGroupPreviews()];
    documents.sort((a, b) => (DateTime.tryParse(b.updatedAt) ??
            DateTime.tryParse(b.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(DateTime.tryParse(a.updatedAt) ??
            DateTime.tryParse(a.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return MediaLinkedOverview(albums: albums, documents: documents);
  }
}

enum MediaLinkedSection { memories, documents }

/// Reuses the original memory album details/gallery and scanner page editor.
/// The Media Studio links are navigational, never a second source of truth.
class MediaLinkedLibrariesScreen extends ConsumerStatefulWidget {
  const MediaLinkedLibrariesScreen({super.key, required this.initialSection});
  final MediaLinkedSection initialSection;

  @override
  ConsumerState<MediaLinkedLibrariesScreen> createState() =>
      _MediaLinkedLibrariesScreenState();
}

class _MediaLinkedLibrariesScreenState
    extends ConsumerState<MediaLinkedLibrariesScreen> {
  late MediaLinkedSection _section;
  late Future<MediaLinkedOverview> _future;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _reload();
  }

  void _reload() {
    _future = MediaLinkedLibrariesService(
      ref.read(scanGroupServiceProvider),
    ).load();
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _future;
    } catch (_) {
      // FutureBuilder renders the error and permits retry.
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openAlbum(LinkedMemoryAlbum album) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => FamilyTreeDetailScreen(
        treeId: album.archive.id,
        initialTabIndex: 2,
        initialMemoryId: album.memory.id,
      )),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openDocument(ScanGroupPreview document) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => ScanGroupViewScreen(groupId: document.id)),
    );
    if (mounted) await _refresh();
  }

  Future<void> _openOwnerLibrary() async {
    await Navigator.of(context, rootNavigator: true).push<void>(MaterialPageRoute(
      builder: (_) => _section == MediaLinkedSection.memories
          ? const FamilyTreeHomeScreen()
          : const ScannerGalleryScreen(),
    ));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected libraries'),
        actions: [
          IconButton(
            tooltip: 'Refresh albums and documents',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<MediaLinkedSection>(
                  segments: const [
                    ButtonSegment(
                      value: MediaLinkedSection.memories,
                      icon: Icon(Icons.photo_album_outlined),
                      label: Text('Memories'),
                    ),
                    ButtonSegment(
                      value: MediaLinkedSection.documents,
                      icon: Icon(Icons.document_scanner_outlined),
                      label: Text('Scanned docs'),
                    ),
                  ],
                  selected: {_section},
                  onSelectionChanged: (value) =>
                      setState(() => _section = value.first),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: _section == MediaLinkedSection.memories
                      ? 'Find a memory or life archive'
                      : 'Find a scanned document',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                ),
              ),
            ]),
          ),
          Expanded(child: FutureBuilder<MediaLinkedOverview>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _empty(
                  Icons.error_outline_rounded,
                  'Could not load connected libraries',
                  '${snapshot.error}',
                  'Retry',
                  _refresh,
                );
              }
              final overview = snapshot.data!;
              final term = _search.text.trim().toLowerCase();
              final isMemories = _section == MediaLinkedSection.memories;
              final albums = overview.albums.where((album) =>
                '${album.memory.title} ${album.memory.description} ${album.archive.name}'
                  .toLowerCase().contains(term)).toList();
              final documents = overview.documents.where((document) =>
                '${document.title} ${document.tags}'.toLowerCase().contains(term))
                  .toList();
              final itemCount = isMemories ? albums.length : documents.length;
              if (itemCount == 0) {
                return _empty(
                  isMemories ? Icons.photo_album_outlined
                      : Icons.document_scanner_outlined,
                  term.isNotEmpty ? 'No matches found'
                      : isMemories ? 'No memory albums yet'
                          : 'No scanned documents yet',
                  term.isNotEmpty
                      ? 'Try another search.'
                      : 'Items added in the original ${isMemories ? 'Life Archive' : 'Scanner'} appear here automatically.',
                  term.isNotEmpty ? 'Clear search' :
                      isMemories ? 'Open Life Archives' : 'Open Scanner',
                  term.isNotEmpty ? () {
                    _search.clear();
                    setState(() {});
                  } : _openOwnerLibrary,
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: LayoutBuilder(builder: (context, size) {
                  final width = size.maxWidth;
                  final count = width >= 1050 ? 4 : width >= 720 ? 3 : 2;
                  return GridView.builder(
                    key: ValueKey(_section),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: width < 600 ? .78 : .94,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (context, index) => isMemories
                        ? LinkedMediaTile(
                            title: albums[index].memory.title,
                            subtitle: albums[index].archive.name,
                            footer: '${albums[index].memory.imagePaths.length} photos',
                            thumbnail: albums[index].memory.imagePaths.isNotEmpty
                                ? albums[index].memory.imagePaths.first : null,
                            onTap: () => _openAlbum(albums[index]),
                          )
                        : LinkedMediaTile(
                            title: documents[index].title,
                            subtitle: 'Scanned document',
                            footer: '${documents[index].pageCount} pages',
                            thumbnail: documents[index].thumbnailPath,
                            document: true,
                            onTap: () => _openDocument(documents[index]),
                          ),
                  );
                }),
              );
            },
          )),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Icon(Icons.link_rounded, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 7),
            Expanded(child: Text(
              'Linked to the original libraries; existing albums and documents are unchanged.',
              maxLines: 2,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            )),
            TextButton(onPressed: _openOwnerLibrary,
              child: const Text('Open source')),
          ]),
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String title, String detail,
      String button, VoidCallback onPressed) {
    final scheme = Theme.of(context).colorScheme;
    return Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 54, color: scheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(detail, textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onPressed, child: Text(button)),
      ]),
    ));
  }
}

/// A source-aware thumbnail: local files stay local, and web URLs remain URLs.
class LinkedMediaThumbnail extends StatelessWidget {
  const LinkedMediaThumbnail({super.key, this.path, this.document = false});
  final String? path;
  final bool document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final target = path;
    Widget? image;
    if (target != null && target.isNotEmpty) {
      if (!document && LifeArchiveMedia.canDisplay(target)) {
        image = LifeArchiveMedia.image(target, fit: BoxFit.cover,
          width: double.infinity, height: double.infinity);
      } else if (document) {
        if (target.startsWith('https://') || target.startsWith('http://')) {
          image = Image.network(target, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(scheme));
        } else if (!kIsWeb && File(target).existsSync()) {
          image = Image.file(File(target), fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(scheme));
        }
      }
    }
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: image ?? _placeholder(scheme),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Center(child: Icon(
    document ? Icons.description_outlined : Icons.photo_album_outlined,
    size: 45, color: scheme.onSurfaceVariant,
  ));
}

class LinkedMediaTile extends StatelessWidget {
  const LinkedMediaTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.onTap,
    this.thumbnail,
    this.document = false,
  });
  final String title;
  final String subtitle;
  final String footer;
  final String? thumbnail;
  final bool document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: LinkedMediaThumbnail(
            path: thumbnail, document: document)),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(document ? Icons.layers_outlined : Icons.image_outlined,
                    size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(child: Text(footer,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant))),
                  Icon(Icons.chevron_right_rounded,
                    size: 17, color: scheme.onSurfaceVariant),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// Home-page entry point: the two sections and recent albums/documents are
/// included in Media Studio without changing its existing Collections/Library.
class MediaLinkedOverviewSection extends StatelessWidget {
  const MediaLinkedOverviewSection({
    super.key,
    required this.overview,
    required this.onBrowseMemories,
    required this.onBrowseDocuments,
    required this.onOpenAlbum,
    required this.onOpenDocument,
  });
  final Future<MediaLinkedOverview> overview;
  final VoidCallback onBrowseMemories;
  final VoidCallback onBrowseDocuments;
  final ValueChanged<LinkedMemoryAlbum> onOpenAlbum;
  final ValueChanged<ScanGroupPreview> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FutureBuilder<MediaLinkedOverview>(
      future: overview,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Connected libraries',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Browse your Life Archive albums and scanned documents here. Originals stay in their existing libraries.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 500;
            final tiles = [
              _libraryCard(context, Icons.photo_album_outlined,
                'Memory albums', '${data?.albums.length ?? '—'} albums',
                onBrowseMemories),
              _libraryCard(context, Icons.document_scanner_outlined,
                'Scanned documents', '${data?.documents.length ?? '—'} documents',
                onBrowseDocuments),
            ];
            return twoColumns ? Row(children: [
              Expanded(child: tiles[0]), const SizedBox(width: 12),
              Expanded(child: tiles[1]),
            ]) : Column(children: [tiles[0], const SizedBox(height: 10), tiles[1]]);
          }),
          if (snapshot.hasError) ...[
            const SizedBox(height: 9),
            Text('Unable to show previews. You can still open either library.',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
          ],
          if (data != null && data.albums.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionHeading(context, 'Recent memory albums', onBrowseMemories),
            const SizedBox(height: 10),
            SizedBox(height: 218, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: (data.albums.length < 5 ? data.albums.length : 5),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final album = data.albums[index];
                return SizedBox(width: 170, child: LinkedMediaTile(
                  title: album.memory.title,
                  subtitle: album.archive.name,
                  footer: '${album.memory.imagePaths.length} photos',
                  thumbnail: album.memory.imagePaths.isNotEmpty
                      ? album.memory.imagePaths.first : null,
                  onTap: () => onOpenAlbum(album),
                ));
              },
            )),
          ],
          if (data != null && data.documents.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionHeading(context, 'Recent scanned documents', onBrowseDocuments),
            const SizedBox(height: 10),
            SizedBox(height: 218, child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: (data.documents.length < 5 ? data.documents.length : 5),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final document = data.documents[index];
                return SizedBox(width: 170, child: LinkedMediaTile(
                  title: document.title,
                  subtitle: 'Scanned document',
                  footer: '${document.pageCount} pages',
                  thumbnail: document.thumbnailPath,
                  document: true,
                  onTap: () => onOpenDocument(document),
                ));
              },
            )),
          ],
          const SizedBox(height: 20),
        ]);
      },
    );
  }

  Widget _sectionHeading(BuildContext context, String title, VoidCallback browse) =>
      Row(children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700))),
        TextButton(onPressed: browse, child: const Text('View all')),
      ]);

  Widget _libraryCard(BuildContext context, IconData icon, String name,
      String count, VoidCallback onTap) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(count, style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant)),
            ],
          )),
          Icon(Icons.arrow_forward_ios_rounded,
            size: 15, color: scheme.onSurfaceVariant),
        ]),
      )),
    );
  }
}
