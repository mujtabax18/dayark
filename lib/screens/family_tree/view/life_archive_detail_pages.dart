import 'package:flutter/material.dart';

import 'life_archive_media.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';
import '../models/life_archive_models.dart';
import 'family_photo_gallery.dart';
import 'life_archive_desktop_widgets.dart';

part 'life_archive_desktop_detail_pages.dart';

/// Dedicated, full-screen previews. Editing still uses the existing forms and
/// repositories, so this does not introduce a second persistence path.
class LifeArchiveMemoryPage extends StatelessWidget {
  const LifeArchiveMemoryPage({
    super.key,
    required this.memory,
    required this.people,
    required this.onEdit,
    required this.onDelete,
    this.event,
    this.onEventTap,
  });

  final FamilyMemory memory;
  final List<FamilyMember> people;
  final LifeEvent? event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onEventTap;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= LifeArchiveDesktop.breakpoint) {
      return _DesktopMemoryDetail(page: this);
    }
    final scheme = Theme.of(context).colorScheme;
    final photos = memory.imagePaths.where((path) => LifeArchiveMedia.canDisplay(path)).toList();
    final date = memory.memoryDate;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory album'),
        actions: [
          IconButton(tooltip: 'Edit memory', onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined)),
          PopupMenuButton<String>(
            tooltip: 'Memory actions',
            onSelected: (action) { if (action == 'delete') onDelete(); },
            itemBuilder: (_) => const [PopupMenuItem(
              value: 'delete',
              child: ListTile(leading: Icon(Icons.delete_outline_rounded),
                title: Text('Delete memory'), contentPadding: EdgeInsets.zero),
            )],
          ),
        ],
      ),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 23, 20, 15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(memory.title, style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (date != null) Chip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 17),
                label: Text(DateFormat.yMMMd().format(date))),
              Chip(avatar: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text('${photos.length} photos')),
              if (event != null) ActionChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(event!.title), onPressed: onEventTap),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: Text('Gallery', style: Theme.of(context)
                  .textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              Text('${photos.length} photos', style: TextStyle(
                  color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 7),
            Text('Select a photo to view it full screen.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant)),
          ]),
        )),
        if (photos.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            sliver: SliverLayoutBuilder(builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 750 ? 4
                  : constraints.crossAxisExtent >= 480 ? 3 : 2;
              return SliverGrid.builder(
                itemCount: photos.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns, crossAxisSpacing: 6,
                  mainAxisSpacing: 6, childAspectRatio: 1),
                itemBuilder: (context, index) => _ArchivePhotoTile(
                  path: photos[index], onTap: () => showFullscreenFamilyPhotos(
                    context, photos, initialIndex: index, title: memory.title)),
              );
            }),
          )
        else
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Icon(Icons.photo_library_outlined, size: 48,
                  color: scheme.onSurfaceVariant),
                const SizedBox(height: 10),
                const Text('No photos added to this memory yet.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: onEdit,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add photos')),
              ]),
            ),
          )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 38),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('The story', style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SelectableText(memory.description.trim().isEmpty
                ? 'No story added yet.' : memory.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55)),
            const SizedBox(height: 24),
            Text('People in this memory',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (people.isEmpty) const Text('Nobody tagged yet.')
            else Wrap(spacing: 8, runSpacing: 8,
              children: people.map((person) => Chip(
                avatar: _ArchivePersonAvatar(person: person),
                label: Text(person.fullName),
              )).toList()),
          ]),
        )),
      ]),
    );
  }
}

class LifeArchiveEventPage extends StatelessWidget {
  const LifeArchiveEventPage({
    super.key,
    required this.event,
    required this.people,
    required this.memories,
    required this.onEdit,
    required this.onDelete,
    required this.onAddMemory,
    required this.onMemoryTap,
    required this.onPersonTap,
  });

  final LifeEvent event;
  final List<FamilyMember> people;
  final List<FamilyMemory> memories;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddMemory;
  final ValueChanged<FamilyMemory> onMemoryTap;
  final ValueChanged<FamilyMember> onPersonTap;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= LifeArchiveDesktop.breakpoint) {
      return _DesktopEventDetail(page: this);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = event.eventDate;
    final icon = switch (event.type) {
      'travel' => Icons.flight_takeoff_rounded,
      'birthday' => Icons.cake_outlined,
      'wedding' => Icons.favorite_outline_rounded,
      'graduation' => Icons.school_outlined,
      'work' => Icons.work_outline_rounded,
      'achievement' => Icons.emoji_events_outlined,
      _ => Icons.auto_awesome_rounded,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Life event'), actions: [
        IconButton(tooltip: 'Edit event', onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined)),
        PopupMenuButton<String>(
          onSelected: (action) { if (action == 'delete') onDelete(); },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete',
            child: ListTile(leading: Icon(Icons.delete_outline_rounded),
              title: Text('Delete event'), contentPadding: EdgeInsets.zero))],
        ),
      ]),
      body: ListView(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [scheme.primaryContainer, scheme.secondaryContainer]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 34, backgroundColor: scheme.surface,
              child: Icon(icon, size: 33, color: scheme.primary)),
            const SizedBox(height: 22),
            Text(event.title, style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(label: Text(event.displayType)),
              if (date != null) Chip(avatar: const Icon(Icons.event_outlined, size: 16),
                label: Text(DateFormat.yMMMMd().format(date))),
              if (event.location.trim().isNotEmpty)
                Chip(avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text(event.location)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (event.description.trim().isNotEmpty) ...[
              Text('About this event', style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SelectableText(event.description,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
              const SizedBox(height: 28),
            ],
            Text('People (${people.length})', style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (people.isEmpty)
              const Padding(padding: EdgeInsets.only(bottom: 18),
                child: Text('No people tagged yet.'))
            else
              ...people.map((person) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _ArchivePersonAvatar(person: person, radius: 22),
                title: Text(person.fullName),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => onPersonTap(person),
              )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: Text('Memories (${memories.length})',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: onAddMemory,
                icon: const Icon(Icons.add_rounded), label: const Text('Add')),
            ]),
            const SizedBox(height: 8),
            if (memories.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                decoration: BoxDecoration(color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  const Icon(Icons.photo_library_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text('No memories for this event yet.'),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(onPressed: onAddMemory,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add memory')),
                ]),
              )
            else ...memories.map((memory) {
              final cover = memory.imagePaths.where((p) => LifeArchiveMedia.canDisplay(p)).firstOrNull;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onMemoryTap(memory),
                  child: Row(children: [
                    SizedBox(width: 94, height: 94,
                      child: InkWell(
                        onTap: () => onMemoryTap(memory),
                        child: cover == null
                            ? Icon(Icons.collections_outlined, color: scheme.primary)
                            : LifeArchiveMedia.image(cover, fit: BoxFit.cover, cacheWidth: 280,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined)))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(memory.title, maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${memory.imagePaths.length} photos',
                            style: theme.textTheme.bodySmall),
                      ])),
                    const Padding(padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.chevron_right_rounded)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 32),
          ]),
        ),
      ]),
    );
  }
}

class _PhotoCountPill extends StatelessWidget {
  const _PhotoCountPill({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Colors.black.withOpacity(.66),
      borderRadius: BorderRadius.circular(24)),
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 6),
        Text('$count photos', style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700)),
      ])),
  );
}

class _ArchivePhotoTile extends StatelessWidget {
  const _ArchivePhotoTile({required this.path, required this.onTap});
  final String path;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: Material(color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: InkWell(onTap: onTap,
        child: LifeArchiveMedia.image(path, fit: BoxFit.cover,
          cacheWidth: 550,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
    ),
  );
}

class _ArchivePersonAvatar extends StatelessWidget {
  const _ArchivePersonAvatar({required this.person, this.radius = 12});
  final FamilyMember person;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final path = person.profileImagePath;
    final exists = path != null && LifeArchiveMedia.canDisplay(path);
    return CircleAvatar(radius: radius,
      backgroundImage: exists ? LifeArchiveMedia.provider(path!)! : null,
      child: exists ? null : const Icon(Icons.person_outline_rounded, size: 18));
  }
}


