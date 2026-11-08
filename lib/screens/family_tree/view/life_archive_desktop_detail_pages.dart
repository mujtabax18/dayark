part of 'life_archive_detail_pages.dart';

/// Large-screen detail views use the same callbacks and repositories as mobile.
/// The records remain on full routes; no detail bottom sheets are introduced.
class _DesktopMemoryDetail extends StatelessWidget {
  const _DesktopMemoryDetail({required this.page});
  final LifeArchiveMemoryPage page;

  @override
  Widget build(BuildContext context) {
    final memory = page.memory;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final photos = memory.imagePaths.where((p) => LifeArchiveMedia.canDisplay(p)).toList();
    final meta = <Widget>[
      if (memory.memoryDate != null)
        _DesktopDetailLine(icon: Icons.calendar_today_outlined, label: 'Date',
          value: DateFormat.yMMMMd().format(memory.memoryDate!)),
      _DesktopDetailLine(icon: Icons.photo_library_outlined, label: 'Photos',
        value: '${photos.length} in this album'),
      if (page.event != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.event_outlined, color: scheme.primary),
          title: Text(page.event!.title),
          subtitle: const Text('Related event'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: page.onEventTap,
        ),
    ];

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Memory details'), actions: [
        OutlinedButton.icon(onPressed: page.onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit memory')),
        const SizedBox(width: 8),
        PopupMenuButton<String>(tooltip: 'Memory actions',
          onSelected: (action) { if (action == 'delete') page.onDelete(); },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete',
            child: Text('Delete memory'))]),
        const SizedBox(width: 18),
      ]),
      body: SingleChildScrollView(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 52),
          child: LayoutBuilder(builder: (context, constraints) {
            final header = Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LIFE ARCHIVES / MEMORIES',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                Text(memory.title, style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 18),
              ],
            );
            final gallery = Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DesktopDetailPanel(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (photos.isEmpty)
                      Container(height: 260,
                        decoration: BoxDecoration(color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(13)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 55,
                              color: scheme.onSurfaceVariant),
                            const SizedBox(height: 12),
                            const Text('No photos yet'),
                            const SizedBox(height: 8),
                            TextButton.icon(onPressed: page.onEdit,
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: const Text('Add photos')),
                          ])),
                    if (photos.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: Text('Photo gallery',
                          style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900))),
                        Text('${photos.length} photos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant)),
                      ]),
                      const SizedBox(height: 12),
                      LayoutBuilder(builder: (context, constraints) {
                        final cols = constraints.maxWidth >= 610 ? 4 : 3;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: photos.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols, crossAxisSpacing: 8,
                            mainAxisSpacing: 8),
                          itemBuilder: (context, index) => _ArchivePhotoTile(
                            path: photos[index],
                            onTap: () => showFullscreenFamilyPhotos(context,
                              photos, initialIndex: index, title: memory.title)),
                        );
                      }),
                    ],
                  ])),
              ],
            );
            final details = Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopDetailPanel(title: 'Memory information',
                  child: Column(children: meta)),
                const SizedBox(height: 18),
                _DesktopDetailPanel(title: 'The story',
                  child: memory.description.trim().isEmpty
                    ? Text('No story added yet.',
                        style: TextStyle(color: scheme.onSurfaceVariant))
                    : SelectableText(memory.description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))),
                const SizedBox(height: 18),
                _DesktopDetailPanel(title: 'People in this memory',
                  child: page.people.isEmpty
                    ? Text('Nobody tagged yet.',
                        style: TextStyle(color: scheme.onSurfaceVariant))
                    : Wrap(spacing: 8, runSpacing: 8,
                        children: page.people.map((person) => Chip(
                          avatar: _ArchivePersonAvatar(person: person),
                          label: Text(person.fullName))).toList())),
              ],
            );
            if (constraints.maxWidth < 890) return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                header, gallery, const SizedBox(height: 18), details,
              ]);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: gallery),
                  const SizedBox(width: 22),
                  SizedBox(width: 350, child: details),
                ]),
              ]);
          }),
        ),
      ))),
    );
  }
}

class _DesktopEventDetail extends StatelessWidget {
  const _DesktopEventDetail({required this.page});
  final LifeArchiveEventPage page;

  @override
  Widget build(BuildContext context) {
    final event = page.event;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Event details'), actions: [
        OutlinedButton.icon(onPressed: page.onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit event')),
        const SizedBox(width: 8),
        PopupMenuButton<String>(tooltip: 'Event actions',
          onSelected: (action) { if (action == 'delete') page.onDelete(); },
          itemBuilder: (_) => const [PopupMenuItem(value: 'delete',
            child: Text('Delete event'))]),
        const SizedBox(width: 18),
      ]),
      body: SingleChildScrollView(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 55),
          child: LayoutBuilder(builder: (context, constraints) {
            final banner = Container(
              padding: const EdgeInsets.all(27),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [scheme.primaryContainer,
                  scheme.secondaryContainer], begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LIFE ARCHIVES / EVENTS',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  Text(event.title, style: theme.textTheme.headlineMedium
                    ?.copyWith(color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 8, children: [
                    Chip(label: Text(event.displayType)),
                    if (event.eventDate != null)
                      Chip(avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                        label: Text(DateFormat.yMMMMd().format(event.eventDate!))),
                    if (event.location.trim().isNotEmpty)
                      Chip(avatar: const Icon(Icons.location_on_outlined, size: 16),
                        label: Text(event.location)),
                  ]),
                ],
              ),
            );
            final primary = Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopDetailPanel(title: 'About this event',
                  child: event.description.trim().isNotEmpty
                    ? SelectableText(event.description,
                        style: theme.textTheme.bodyMedium?.copyWith(height: 1.6))
                    : Text('No event description added.',
                        style: TextStyle(color: scheme.onSurfaceVariant))),
                const SizedBox(height: 18),
                _DesktopDetailPanel(
                  title: 'Related memories (${page.memories.length})',
                  trailing: TextButton.icon(onPressed: page.onAddMemory,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add memory')),
                  child: page.memories.isEmpty
                    ? Padding(padding: const EdgeInsets.symmetric(vertical: 25),
                        child: Column(children: [
                          Icon(Icons.collections_outlined, size: 42,
                            color: scheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          const Text('No memories for this event.'),
                        ]))
                    : LayoutBuilder(builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 630 ? 3 : 2;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: page.memories.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 10, crossAxisSpacing: 10,
                            childAspectRatio: .95),
                          itemBuilder: (context, index) {
                            final memory = page.memories[index];
                            final cover = memory.imagePaths.where((p) =>
                              LifeArchiveMedia.canDisplay(p)).firstOrNull;
                            return Card(clipBehavior: Clip.antiAlias,
                              margin: EdgeInsets.zero,
                              child: InkWell(onTap: () => page.onMemoryTap(memory),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(child: cover == null
                                      ? Icon(Icons.photo_library_outlined,
                                          color: scheme.primary)
                                      : LifeArchiveMedia.image(cover, fit: BoxFit.cover)),
                                    Padding(padding: const EdgeInsets.all(9),
                                      child: Text(memory.title, maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w800))),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }),
                ),
              ],
            );
            final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopDetailPanel(title: 'Event information', child: Column(
                  children: [
                    _DesktopDetailLine(icon: Icons.bookmark_border_rounded,
                      label: 'Type', value: event.displayType),
                    _DesktopDetailLine(icon: Icons.calendar_month_outlined,
                      label: 'Date', value: event.eventDate == null ? 'Not set'
                        : DateFormat.yMMMMd().format(event.eventDate!)),
                    if (event.location.trim().isNotEmpty)
                      _DesktopDetailLine(icon: Icons.location_on_outlined,
                        label: 'Location', value: event.location),
                  ])),
                const SizedBox(height: 18),
                _DesktopDetailPanel(title: 'People (${page.people.length})',
                  child: page.people.isEmpty
                    ? Text('No people linked yet.',
                      style: TextStyle(color: scheme.onSurfaceVariant))
                    : Column(children: page.people.map((person) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _ArchivePersonAvatar(person: person, radius: 21),
                        title: Text(person.fullName, maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => page.onPersonTap(person),
                      )).toList())),
              ],
            );
            if (constraints.maxWidth < 890) return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                banner, const SizedBox(height: 20), primary,
                const SizedBox(height: 18), side,
              ]);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [banner, const SizedBox(height: 20),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: primary), const SizedBox(width: 22),
                  SizedBox(width: 350, child: side),
                ]),
              ]);
          }),
        ),
      ))),
    );
  }
}

class _DesktopDetailPanel extends StatelessWidget {
  const _DesktopDetailPanel({required this.child, this.title, this.trailing});
  final Widget child;
  final String? title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Row(children: [
            Expanded(child: Text(title!, style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w900))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 17),
        ],
        child,
      ]),
    );
  }
}

class _DesktopDetailLine extends StatelessWidget {
  const _DesktopDetailLine({required this.icon, required this.label,
    required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 15),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: scheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SelectableText(value, style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        )),
      ]),
    );
  }
}
