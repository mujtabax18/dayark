import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import 'life_archive_media.dart';

import '../../../core/design/app_tokens.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../models/family_tree_models.dart';
import '../services/family_tree_repository.dart';
import '../services/life_archive_repository.dart';
import 'family_tree_detail_screen.dart';
import 'life_archive_desktop_widgets.dart';
import '../../navigation/widgets/desktop_content_frame.dart';

class FamilyTreeHomeScreen extends StatefulWidget {
  const FamilyTreeHomeScreen({super.key});

  @override
  State<FamilyTreeHomeScreen> createState() => _FamilyTreeHomeScreenState();
}

class _FamilyTreeHomeScreenState extends State<FamilyTreeHomeScreen> {
  final FamilyTreeRepository _repository = FamilyTreeRepository();
  final LifeArchiveRepository _lifeRepository = LifeArchiveRepository();
  bool _loading = true;
  List<FamilyTree> _trees = const [];
  Map<int, _FamilyPreview> _previews = const {};
  String _archiveQuery = '';
  final TextEditingController _archiveSearchController = TextEditingController();
  int _desktopSection = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _archiveSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trees = await _repository.getTrees();
      final previews = <int, _FamilyPreview>{};
      await Future.wait(trees.map((tree) async {
        final members = await _repository.getMembers(tree.id);
        final results = await Future.wait<Object?>([_repository.getRelationships(tree.id),
          _lifeRepository.getConnections(tree.id), _lifeRepository.getEvents(tree.id),
          _repository.getMemories(tree.id)]);
        previews[tree.id] = _FamilyPreview(members,
          (results[0] as List).length + (results[1] as List).length,
          (results[2] as List).length, (results[3] as List).length);
      }));
      if (!mounted) return;
      setState(() {
        _trees = trees;
        _previews = previews;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showTreeDialog([FamilyTree? tree]) async {
    final savedTreeId = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _FamilyTreeEditorDialog(
        tree: tree,
        repository: _repository,
      ),
    );

    if (savedTreeId == null || !mounted) return;
    await _load();
    if (tree == null && mounted) {
      // Present above the app shell so its bottom bar/FAB cannot steal
      // viewport space or gestures from the interactive tree.
      await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
        builder: (_) => FamilyTreeDetailScreen(treeId: savedTreeId),
      ));
      if (mounted) await _load();
    }
  }

  Future<void> _deleteTree(FamilyTree tree) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete life archive?'),
        content: Text(
          'This permanently deletes “${tree.name}”, all its people, relationships, life events, memories and locally stored images.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await _repository.deleteTree(tree);
    await _load();
  }

  Future<void> _openTree(FamilyTree tree) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyTreeDetailScreen(treeId: tree.id),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => LifeArchiveDesktop.enabled(constraints)
        ? _buildDesktop(context) : _buildMobile(context),
  );

  Widget _buildDesktop(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = [..._trees]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final filtered = all.where((tree) =>
      tree.name.toLowerCase().contains(_archiveQuery.toLowerCase()) ||
      tree.description.toLowerCase().contains(_archiveQuery.toLowerCase())).toList();
    final people = _previews.values.fold<int>(0, (sum, p) => sum + p.members.length);
    final events = _previews.values.fold<int>(0, (sum, p) => sum + p.events);
    final memories = _previews.values.fold<int>(0, (sum, p) => sum + p.memories);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Row(children: [
        ArchiveDesktopSidebar(
          items: const [
            ArchiveNavigationItem('Overview', Icons.dashboard_outlined),
            ArchiveNavigationItem('All archives', Icons.folder_copy_outlined),
          ],
          selectedIndex: _desktopSection,
          onSelected: (index) => setState(() => _desktopSection = index),
          footer: SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh archives'),
          )),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(slivers: [
                  SliverToBoxAdapter(child: ArchiveDesktopWorkspace(child:
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ArchiveDesktopHeader(
                        breadcrumb: 'Workspace / Life Archives',
                        title: _desktopSection == 0 ? 'Life Archives' : 'All archives',
                        subtitle: 'Organize the people, moments, and stories that matter.',
                        actions: [
                          FilledButton.icon(
                            onPressed: () => _showTreeDialog(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New archive'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      if (_desktopSection == 0) ...[
                        LayoutBuilder(builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1120 ? 4 : 2;
                          return GridView.count(
                            crossAxisCount: columns,
                            childAspectRatio: columns == 4 ? 2.55 : 2.8,
                            crossAxisSpacing: 14, mainAxisSpacing: 14,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              ArchiveDesktopStat(label: 'Archives', value: '${_trees.length}',
                                icon: Icons.folder_open_outlined,
                                onTap: () => setState(() => _desktopSection = 1)),
                              ArchiveDesktopStat(label: 'People', value: '$people',
                                icon: Icons.people_alt_outlined),
                              ArchiveDesktopStat(label: 'Events', value: '$events',
                                icon: Icons.event_note_rounded),
                              ArchiveDesktopStat(label: 'Memories', value: '$memories',
                                icon: Icons.photo_library_outlined),
                            ],
                          );
                        }),
                        const SizedBox(height: 30),
                      ],
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_desktopSection == 0 ? 'Your archives' : 'Archive library',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text('${filtered.length} archives • Updated recently first',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant)),
                          ],
                        )),
                        const SizedBox(width: 16),
                        SizedBox(width: 290,
                          child: TextField(
                            controller: _archiveSearchController,
                            onChanged: (value) => setState(() => _archiveQuery = value),
                            decoration: const InputDecoration(
                              hintText: 'Search archives',
                              isDense: true,
                              prefixIcon: Icon(Icons.search_rounded),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 17),
                    ]),
                  )),
                  if (filtered.isEmpty)
                    SliverFillRemaining(hasScrollBody: false,
                      child: _trees.isEmpty
                          ? _EmptyTrees(onCreate: () => _showTreeDialog())
                          : Center(child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.search_off_rounded, size: 46,
                                  color: scheme.onSurfaceVariant),
                                const SizedBox(height: 12),
                                const Text('No archives match your search.'),
                                TextButton(onPressed: () {
                                    _archiveSearchController.clear();
                                    setState(() => _archiveQuery = '');
                                  },
                                  child: const Text('Clear search')),
                              ]),
                            )),
                    )
                  else
                    SliverToBoxAdapter(child: ArchiveDesktopWorkspace(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1000 ? 3
                            : constraints.maxWidth >= 670 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns, mainAxisSpacing: 16,
                            crossAxisSpacing: 16, childAspectRatio: columns == 3 ? 1.65 : columns == 2 ? 1.85 : 2.5),
                          itemBuilder: (context, index) {
                            final tree = filtered[index];
                            return _ArchiveDesktopCard(
                              tree: tree,
                              preview: _previews[tree.id],
                              onOpen: () => _openTree(tree),
                              onEdit: () => _showTreeDialog(tree),
                              onDelete: () => _deleteTree(tree),
                            );
                          },
                        );
                      }),
                    )),
                ]),
              )),
      ]),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Archives'),
        actions: [
          IconButton(
            tooltip: 'Create life archive',
            onPressed: () => _showTreeDialog(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTreeDialog(),
        icon: const Icon(Icons.account_tree_outlined),
        label: const Text('New archive'),
      ),
      body: DesktopContentFrame(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _trees.isEmpty
              ? _EmptyTrees(onCreate: () => _showTreeDialog())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      112,
                    ),
                    itemCount: _trees.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final tree = _trees[index];
                      final preview = _previews[tree.id];
                      return AppSurface(
                        onTap: () => _openTree(tree),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 75,
                              height: 64,
                              child: Stack(children: [
                                for (var i = 0; i < (preview?.members.length ?? 0) && i < 3; i++)
                                  Positioned(
                                    left: i * 16.0,
                                    top: i.isEven ? 2.0 : 13.0,
                                    child: CircleAvatar(
                                      radius: 19,
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      backgroundImage: preview!.members[i].profileImagePath != null &&
                                          LifeArchiveMedia.canDisplay(preview.members[i].profileImagePath!)
                                          ? LifeArchiveMedia.provider(preview.members[i].profileImagePath!)! : null,
                                      child: preview.members[i].profileImagePath != null &&
                                          LifeArchiveMedia.canDisplay(preview.members[i].profileImagePath!)
                                          ? null : const Icon(Icons.person_outline_rounded, size: 23),
                                    ),
                                  ),
                                if (preview == null || preview.members.isEmpty)
                                  Align(alignment: Alignment.centerLeft,
                                    child: Icon(Icons.account_tree_outlined,
                                      color: Theme.of(context).colorScheme.primary, size: 38)),
                              ]),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tree.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${preview?.members.length ?? 0} people · ${preview?.relations ?? 0} links · ${preview?.events ?? 0} events',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  if (tree.description.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      tree.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _showTreeDialog(tree);
                                if (value == 'delete') _deleteTree(tree);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}



class _ArchiveDesktopCard extends StatelessWidget {
  const _ArchiveDesktopCard({required this.tree, required this.preview,
    required this.onOpen, required this.onEdit, required this.onDelete});

  final FamilyTree tree;
  final _FamilyPreview? preview;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cover = tree.coverImagePath;
    final showCover = cover != null && LifeArchiveMedia.canDisplay(cover);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(onTap: onOpen, child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: Stack(fit: StackFit.expand, children: [
            if (showCover)
              LifeArchiveMedia.image(cover!, fit: BoxFit.cover, cacheWidth: 900)
            else
              ColoredBox(color: scheme.primaryContainer,
                child: Align(alignment: Alignment.center,
                  child: Icon(Icons.auto_stories_rounded,
                    size: 54, color: scheme.onPrimaryContainer))),
            Positioned(right: 10, top: 10,
              child: Material(
                color: scheme.surface.withOpacity(.95),
                borderRadius: BorderRadius.circular(12),
                child: PopupMenuButton<String>(
                  tooltip: 'Archive actions',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit archive')),
                    PopupMenuItem(value: 'delete', child: Text('Delete archive')),
                  ],
                ),
              ),
            ),
          ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tree.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
              if (tree.description.trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(tree.description, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 9),
              Text('${preview?.members.length ?? 0} people  •  '
                   '${preview?.events ?? 0} events  •  '
                   '${preview?.memories ?? 0} memories',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      )),
    );
  }
}

class _FamilyTreeEditorDialog extends StatefulWidget {
  const _FamilyTreeEditorDialog({
    required this.tree,
    required this.repository,
  });

  final FamilyTree? tree;
  final FamilyTreeRepository repository;

  @override
  State<_FamilyTreeEditorDialog> createState() => _FamilyTreeEditorDialogState();
}

class _FamilyTreeEditorDialogState extends State<_FamilyTreeEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _name;
  late String _description;
  final _startingName = TextEditingController();
  final _picker = ImagePicker();
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = widget.tree?.name ?? '';
    _description = widget.tree?.description ?? '';
  }

  @override
  void dispose() {
    _startingName.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 86);
      if (photo != null && mounted) setState(() => _photoPath = photo.path);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not select photo: $error')),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    _formKey.currentState?.save();

    setState(() => _saving = true);

    try {
      final tree = widget.tree;
      int treeId;
      if (tree == null) {
        if (_startingName.text.trim().isEmpty) {
          // A life archive may begin with events or memories rather than a person.
          treeId = await widget.repository.createTree(
            name: _name.trim(), description: _description.trim());
        } else {
          treeId = await widget.repository.createTreeWithFirstMember(
            name: _name.trim(), description: _description.trim(),
            firstMemberName: _startingName.text.trim(), imageSourcePath: _photoPath);
        }
      } else {
        treeId = tree.id;
        await widget.repository.updateTree(
          treeId: tree.id,
          name: _name.trim(),
          description: _description.trim(),
          coverImagePath: tree.coverImagePath,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(treeId);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save life archive: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.tree == null ? 'Create life archive' : 'Edit life archive'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Archive name',
                  hintText: 'e.g. My Life, Our People',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Please enter an archive name.'
                    : null,
                onSaved: (value) => _name = value?.trim() ?? '',
              ),
              if (widget.tree == null) ...[
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _startingName,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Starting person (optional)',
                    hintText: 'e.g. Muhammad Ahmed',
                    helperText: 'Or leave blank and start with a life event.',
                  ),
                  validator: (_) => null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundImage: _photoPath != null && LifeArchiveMedia.canDisplay(_photoPath!)
                      ? LifeArchiveMedia.provider(_photoPath!)! : null,
                    child: _photoPath == null
                      ? const Icon(Icons.person_outline_rounded) : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton.icon(
                    onPressed: _saving ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_photoPath == null ? 'Add optional photo' : 'Change photo'),
                  ),
                ]),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                initialValue: _description,
                minLines: 3,
                maxLines: 5,
                enabled: !_saving,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What people and moments will you remember here?',
                  alignLabelWithHint: true,
                ),
                onSaved: (value) => _description = value?.trim() ?? '',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.tree == null ? 'Create & start' : 'Save'),
        ),
      ],
    );
  }
}

class _EmptyTrees extends StatelessWidget {
  const _EmptyTrees({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_tree_outlined,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your people. Your stories. Your life.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Start with one person. Grow a private network of family, friends, meaningful connections, milestones and photo memories. Stored locally on your device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create first archive'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyPreview {
  const _FamilyPreview(this.members, this.relations, this.events, this.memories);
  final List<FamilyMember> members;
  final int relations;
  final int events;
  final int memories;
}
