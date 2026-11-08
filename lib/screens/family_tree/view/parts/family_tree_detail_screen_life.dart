part of '../family_tree_detail_screen.dart';

/// Forms remain sheets; event previews are full pages. Both use WebView
/// suspension so native desktop surfaces never obscure Flutter routes.
extension _LifeArchiveActions on _FamilyTreeDetailScreenState {
  Future<void> _showLifeConnectionForm({FamilyMember? anchor,
    LifeConnection? connection}) async {
    final changed = await _showFamilyModal<bool>(builder: (_) =>
      LifeConnectionSheet(treeId: widget.treeId, people: _members,
        repository: _lifeRepository, anchor: anchor, connection: connection));
    if (changed == true && mounted) await _load();
  }

  Future<bool> _showLifeEventForm({LifeEvent? event, int? initialPersonId}) async {
    final changed = await _showFamilyModal<bool>(builder: (_) =>
      LifeEventFormSheet(treeId: widget.treeId, people: _members,
        repository: _lifeRepository, event: event,
        initialPersonId: initialPersonId));
    if (changed == true && mounted) await _load();
    return changed == true;
  }

  Future<bool> _deleteLifeEvent(LifeEvent event) async {
    final confirmed = await showDialog<bool>(context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete life event?'),
        content: Text('Remove “${event.title}”? Linked memories will be kept but unlinked from this event.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Delete')),
        ],
      ));
    if (confirmed != true) return false;
    try {
      await _lifeRepository.deleteEvent(widget.treeId, event.id);
      if (mounted) await _load();
      return true;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete event: $error')));
      return false;
    }
  }

  Future<void> _showLifeEventDetails(LifeEvent event) async {
    if (MediaQuery.sizeOf(context).width >= LifeArchiveDesktop.breakpoint) {
      await _selectInspector(eventId: event.id);
      return;
    }
    final albums = _memories.where((memory) => memory.eventId == event.id).toList();
    final people = event.participantIds.map(_memberById)
        .whereType<FamilyMember>().toList();
    await _showArchivePage<void>((pageContext) => LifeArchiveEventPage(
      event: event,
      people: people,
      memories: albums,
      onEdit: () async {
        final changed = await _showLifeEventForm(event: event);
        if (changed && pageContext.mounted) Navigator.of(pageContext).pop();
      },
      onDelete: () async {
        final deleted = await _deleteLifeEvent(event);
        if (deleted && pageContext.mounted) Navigator.of(pageContext).pop();
      },
      onAddMemory: () async {
        final changed = await _showMemoryForm(initialEventId: event.id);
        if (changed && pageContext.mounted) Navigator.of(pageContext).pop();
      },
      onMemoryTap: _showMemoryDetails,
      onPersonTap: _showMemberDetails,
    ));
  }
}

class _LifeEventsTab extends StatefulWidget {
  const _LifeEventsTab({required this.events, required this.onAdd,
    required this.onTap, this.selectedEventId});
  final int? selectedEventId;
  final List<LifeEvent> events;
  final VoidCallback onAdd;
  final ValueChanged<LifeEvent> onTap;

  @override
  State<_LifeEventsTab> createState() => _LifeEventsTabState();
}

class _LifeEventsTabState extends State<_LifeEventsTab> {
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  String _type = 'all';
  bool _newestFirst = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconFor(LifeEvent event) => switch (event.type) {
    'travel' => Icons.flight_takeoff_outlined,
    'birthday' => Icons.cake_outlined,
    'wedding' => Icons.favorite_outline_rounded,
    'graduation' => Icons.school_outlined,
    'work' => Icons.work_outline_rounded,
    'achievement' => Icons.emoji_events_outlined,
    _ => Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) return _ModuleEmptyState(
      icon: Icons.event_note_outlined,
      title: 'Your timeline starts here',
      description: 'Remember milestones, trips, celebrations, work achievements and the people involved.',
      buttonLabel: 'Add first event', onPressed: widget.onAdd,
    );
    return MediaQuery.sizeOf(context).width >= LifeArchiveDesktop.breakpoint
        ? _buildDesktop(context) : _buildMobile(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _searchText.trim().toLowerCase();
    final filtered = widget.events.where((event) =>
        (_type == 'all' || event.type == _type) &&
        (query.isEmpty || [event.title, event.description, event.location,
          event.displayType].any((value) => value.toLowerCase().contains(query))))
        .toList()
      ..sort((a, b) {
        final aDate = a.eventDate;
        final bDate = b.eventDate;
        if (aDate == null && bDate == null) return a.title.compareTo(b.title);
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return _newestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
      });

    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Events management', style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${filtered.length} of ${widget.events.length} events',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
              ],
            )),
            IconButton(tooltip: 'Add new event', onPressed: widget.onAdd,
              icon: const Icon(Icons.add_circle_outline_rounded)),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 14, runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 295, child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchText = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search events or locations',
                  border: OutlineInputBorder(), isDense: true,
                ),
              )),
              DropdownButton<String>(
                value: _type,
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All event types')),
                  ...LifeEvent.types.entries.map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value))),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'all'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: Text(_newestFirst ? 'Newest first' : 'Oldest first'),
              ),
            ]),
        ]),
      ),
      Expanded(child: filtered.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            const Text('No events match the selected filters.'),
            TextButton(onPressed: () {
              _searchController.clear();
              setState(() { _searchText = ''; _type = 'all'; });
            }, child: const Text('Clear filters')),
          ]))
        : LayoutBuilder(builder: (context, constraints) =>
            constraints.maxWidth >= 940
                ? _buildTable(context, filtered)
                : _buildCards(context, filtered))),
    ]);
  }

  Widget _buildTable(BuildContext context, List<LifeEvent> events) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(color: scheme.surfaceContainerLow, padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          child: Row(children: const [
            Expanded(flex: 4, child: Text('EVENT', style: TextStyle(fontWeight: FontWeight.w800))),
            Expanded(flex: 2, child: Text('TYPE', style: TextStyle(fontWeight: FontWeight.w800))),
            Expanded(flex: 2, child: Text('DATE', style: TextStyle(fontWeight: FontWeight.w800))),
            Expanded(flex: 3, child: Text('LOCATION', style: TextStyle(fontWeight: FontWeight.w800))),
            Expanded(flex: 2, child: Text('LINKED', style: TextStyle(fontWeight: FontWeight.w800))),
            SizedBox(width: 28),
          ]),
        ),
        Expanded(child: ListView.separated(
          itemCount: events.length,
          separatorBuilder: (_, __) => Divider(height: 1,
            color: scheme.outlineVariant),
          itemBuilder: (context, index) {
            final event = events[index];
            return Material(
              color: widget.selectedEventId == event.id
                  ? scheme.primaryContainer.withOpacity(.3) : Colors.transparent,
              child: InkWell(
                onTap: () => widget.onTap(event),
                child: Padding(padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 14),
                  child: Row(children: [
                    Expanded(flex: 4, child: Row(children: [
                      CircleAvatar(radius: 19,
                        backgroundColor: scheme.primaryContainer,
                        child: Icon(_iconFor(event), size: 19,
                          color: scheme.onPrimaryContainer)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(event.title, maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                    ])),
                    Expanded(flex: 2, child: Text(event.displayType,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(event.eventDate == null ? 'Not set'
                        : DateFormat.yMMMd().format(event.eventDate!),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 3, child: Text(event.location.isEmpty ? '—' : event.location,
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 2, child: Text(
                      '${event.participantIds.length} people · ${event.albumCount} albums',
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 28,
                      child: Icon(Icons.chevron_right_rounded)),
                  ]),
                ),
              ),
            );
          },
        )),
      ]),
    );
  }

  Widget _buildCards(BuildContext context, List<LifeEvent> events) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 560 ? 2 : 1;
      return GridView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: events.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: columns == 2 ? 1.65 : 3,
        ),
        itemBuilder: (context, index) {
          final event = events[index];
          return Card(
            margin: EdgeInsets.zero, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.selectedEventId == event.id
                    ? scheme.primary : scheme.outlineVariant,
                width: widget.selectedEventId == event.id ? 2 : 1)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: () => widget.onTap(event),
              child: Padding(padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(_iconFor(event), color: scheme.primary),
                    const Spacer(),
                    Text(event.displayType,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant)),
                  ]),
                  const Spacer(),
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 7),
                  Text([if (event.eventDate != null)
                    DateFormat.yMMMd().format(event.eventDate!),
                    if (event.location.isNotEmpty) event.location,
                  ].join('  •  '), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text('${event.participantIds.length} people · ${event.albumCount} memories',
                    style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: scheme.primary)),
                ]),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildMobile(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
      AppSpacing.lg, 112),
    itemCount: widget.events.length,
    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
    itemBuilder: (context, index) {
      final event = widget.events[index];
      final date = event.eventDate;
      return AppSurface(
        onTap: () => widget.onTap(event),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 25, child: Icon(_iconFor(event))),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text([event.displayType,
                if (date != null) DateFormat.yMMMd().format(date),
                if (event.location.isNotEmpty) event.location].join(' · '),
                style: Theme.of(context).textTheme.bodySmall),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 5),
              Text('${event.participantIds.length} people · ${event.albumCount} memories',
                style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
          const Icon(Icons.chevron_right_rounded),
        ]),
      );
    },
  );
}
