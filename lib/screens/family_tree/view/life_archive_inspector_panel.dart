import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/family_tree_models.dart';
import '../models/life_archive_models.dart';
import 'life_archive_media.dart';

/// In-workspace detail inspector for the desktop/web Life Archive.
/// This is deliberately not a Route, Scaffold, bottom sheet or photo carousel.
/// The underlying list remains mounted and keeps its filter/scroll state.
class LifeArchiveInspectorPanel extends StatelessWidget {
  const LifeArchiveInspectorPanel({
    super.key,
    this.memory,
    this.event,
    required this.people,
    required this.relatedMemories,
    required this.relatedEvent,
    required this.onClose,
    this.onBack,
    required this.onEdit,
    required this.onDelete,
    required this.onSelectMemory,
    required this.onSelectEvent,
    required this.onSelectPerson,
    required this.onViewPhoto,
    required this.onAddMemory,
  }) : assert((memory == null) != (event == null),
           'Supply exactly one memory or event.');

  final FamilyMemory? memory;
  final LifeEvent? event;
  final List<FamilyMember> people;
  final List<FamilyMemory> relatedMemories;
  final LifeEvent? relatedEvent;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<FamilyMemory> onSelectMemory;
  final ValueChanged<LifeEvent> onSelectEvent;
  final ValueChanged<FamilyMember> onSelectPerson;
  final void Function(List<String> paths, int index, String title) onViewPhoto;
  final VoidCallback onAddMemory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMemory = memory != null;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(left: false, right: false, bottom: false, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
              child: Row(children: [
                if (onBack != null)
                  IconButton(
                    tooltip: 'Previous details',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                else
                  Icon(isMemory ? Icons.collections_outlined
                    : Icons.event_note_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isMemory ? 'MEMORY ALBUM' : 'LIFE EVENT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary, fontWeight: FontWeight.w800,
                        letterSpacing: 1.0)),
                    const SizedBox(height: 3),
                    Text(memory?.title ?? event!.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800)),
                  ],
                )),
                IconButton(
                  tooltip: isMemory ? 'Edit memory' : 'Edit event',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More actions',
                  onSelected: (choice) {
                    if (choice == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded, size: 19),
                      const SizedBox(width: 10),
                      Text(isMemory ? 'Delete memory' : 'Delete event'),
                    ]),
                  )],
                ),
                IconButton(
                  tooltip: 'Close details',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ]),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Expanded(child: isMemory ? _memoryContent(context) : _eventContent(context)),
          ],
        )),
      ),
    );
  }

  Widget _memoryContent(BuildContext context) {
    final current = memory!;
    final scheme = Theme.of(context).colorScheme;
    final photos = current.imagePaths
        .where((path) => LifeArchiveMedia.canDisplay(path)).toList();
    return CustomScrollView(
      key: PageStorageKey<String>('memory-inspector-${current.id}'),
      slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(current.title, style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 13),
            Wrap(spacing: 7, runSpacing: 5, children: [
              if (current.memoryDate != null) Chip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(DateFormat.yMMMd().format(current.memoryDate!))),
              Chip(avatar: const Icon(Icons.photo_library_outlined, size: 16),
                label: Text('${photos.length} photos')),
            ]),
            if (relatedEvent != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => onSelectEvent(relatedEvent!),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: FlexibleLabel(relatedEvent!.title),
              ),
            ],
            const SizedBox(height: 21),
            Row(children: [
              Expanded(child: Text('Album gallery',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800))),
              Text('${photos.length} photos', style: Theme.of(context)
                  .textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            Text('Select a photo to view it full screen.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant)),
          ]),
        )),
        if (photos.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverLayoutBuilder(builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 390 ? 3 : 2;
              return SliverGrid.builder(
                itemCount: photos.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 7, mainAxisSpacing: 7,
                ),
                itemBuilder: (context, index) => Semantics(
                  label: 'Open photo ${index + 1} of ${photos.length}',
                  button: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Material(
                      color: scheme.surfaceContainerLow,
                      child: InkWell(
                        onTap: () => onViewPhoto(photos, index, current.title),
                        child: LifeArchiveMedia.image(photos[index],
                          fit: BoxFit.cover, cacheWidth: 450,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          )
        else
          SliverToBoxAdapter(child: _emptyMessage(context,
              'This album has no photos yet.', Icons.photo_library_outlined,
              onAction: onEdit, actionLabel: 'Add photos')),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 25, 20, 35),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionTitle(context, 'The story'),
            const SizedBox(height: 9),
            SelectableText(current.description.trim().isEmpty
              ? 'No story added yet.' : current.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55)),
            const SizedBox(height: 24),
            _sectionTitle(context, 'People (${people.length})'),
            const SizedBox(height: 9),
            if (people.isEmpty) const Text('Nobody tagged yet.')
            else Wrap(spacing: 7, runSpacing: 6, children: people.map((person) =>
              ActionChip(
                avatar: const Icon(Icons.person_outline_rounded, size: 16),
                label: Text(person.fullName),
                onPressed: () => onSelectPerson(person),
              )).toList()),
          ]),
        )),
      ],
    );
  }

  Widget _eventContent(BuildContext context) {
    final current = event!;
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      key: PageStorageKey<String>('event-inspector-${current.id}'),
      slivers: [
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(current.title, style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 13),
            Wrap(spacing: 7, runSpacing: 6, children: [
              Chip(label: Text(current.displayType)),
              if (current.eventDate != null) Chip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(DateFormat.yMMMd().format(current.eventDate!))),
            ]),
            if (current.location.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_on_outlined, size: 19, color: scheme.primary),
                const SizedBox(width: 7),
                Expanded(child: Text(current.location)),
              ]),
            ],
            const SizedBox(height: 23),
            _sectionTitle(context, 'About this event'),
            const SizedBox(height: 9),
            SelectableText(current.description.trim().isEmpty
              ? 'No description added yet.' : current.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55)),
            const SizedBox(height: 23),
            _sectionTitle(context, 'People (${people.length})'),
            const SizedBox(height: 8),
            if (people.isEmpty) const Text('No people linked yet.')
            else Wrap(spacing: 7, runSpacing: 6,
              children: people.map((person) => ActionChip(
                avatar: const Icon(Icons.person_outline_rounded, size: 16),
                label: Text(person.fullName),
                onPressed: () => onSelectPerson(person),
              )).toList()),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: _sectionTitle(context,
                  'Memory albums (${relatedMemories.length})')),
              IconButton(
                tooltip: 'Add memory to event',
                onPressed: onAddMemory,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ]),
            const SizedBox(height: 5),
          ]),
        )),
        if (relatedMemories.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            sliver: SliverLayoutBuilder(builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 390 ? 3 : 2;
              return SliverGrid.builder(
                itemCount: relatedMemories.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns, crossAxisSpacing: 8,
                  mainAxisSpacing: 9, childAspectRatio: .73),
                itemBuilder: (context, index) {
                  final album = relatedMemories[index];
                  final cover = album.imagePaths.where((p) =>
                    LifeArchiveMedia.canDisplay(p)).firstOrNull;
                  return Semantics(
                    button: true, label: 'Open gallery ${album.title}',
                    child: Material(
                      clipBehavior: Clip.antiAlias,
                      color: scheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: scheme.outlineVariant)),
                      child: InkWell(
                        onTap: () => onSelectMemory(album),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: cover == null
                              ? Icon(Icons.photo_library_outlined, color: scheme.primary)
                              : LifeArchiveMedia.image(cover, fit: BoxFit.cover,
                                  cacheWidth: 420)),
                            Padding(padding: const EdgeInsets.all(7),
                              child: Text(album.title, maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(fontWeight: FontWeight.w800))),
                          ]),
                      ),
                    ),
                  );
                },
              );
            }),
          )
        else
          SliverToBoxAdapter(child: _emptyMessage(context,
              'No memory albums linked to this event.',
              Icons.collections_outlined,
              onAction: onAddMemory, actionLabel: 'Add memory')),
      ],
    );
  }

  Widget _emptyMessage(BuildContext context, String text, IconData icon,
      {required VoidCallback onAction, required String actionLabel}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(icon, size: 35, color: scheme.onSurfaceVariant),
          const SizedBox(height: 9),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 11),
          TextButton.icon(onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: Text(actionLabel)),
        ]),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800));
}

/// Uses a compact label in buttons even when event titles are very long.
class FlexibleLabel extends StatelessWidget {
  const FlexibleLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      maxLines: 1, overflow: TextOverflow.ellipsis);
}
