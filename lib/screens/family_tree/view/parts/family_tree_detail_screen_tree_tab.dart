part of '../family_tree_detail_screen.dart';

class _TreeTab extends StatefulWidget {
  const _TreeTab({
    required this.constellationKey,
    required this.suspendWebView,
    required this.members,
    required this.relationships,
    required this.connections,
    required this.events,
    required this.focusedMemberId,
    required this.onFocus,
    required this.onAddPerson,
    required this.onAddEvent,
    required this.onEventTap,
    required this.onAddAlbumForEvent,
    required this.onConnect,
    required this.onAddRelative,
    required this.onMemberTap,
  });

  final GlobalKey<FamilyConstellationViewState> constellationKey;
  final bool suspendWebView;
  final List<FamilyMember> members;
  final List<FamilyRelationship> relationships;
  final List<LifeConnection> connections;
  final List<LifeEvent> events;
  final int? focusedMemberId;
  final ValueChanged<int> onFocus;
  final VoidCallback onAddPerson;
  final VoidCallback onAddEvent;
  final ValueChanged<LifeEvent> onEventTap;
  final ValueChanged<LifeEvent> onAddAlbumForEvent;
  final ValueChanged<FamilyMember> onConnect;
  final void Function(FamilyMember, String) onAddRelative;
  final ValueChanged<FamilyMember> onMemberTap;

  @override
  State<_TreeTab> createState() => _TreeTabState();
}

class _TreeTabState extends State<_TreeTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty && widget.events.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.hub_outlined, size: 56),
          const SizedBox(height: AppSpacing.md),
          Text('Start your life constellation',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          const Text('Start with someone important or a memorable life event.',
            textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(onPressed: widget.onAddPerson,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Add person')),
              OutlinedButton.icon(onPressed: widget.onAddEvent,
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Add life event')),
            ]),
        ]),
      ));
    }
    // Occupies the entire Tree tab. The HTML surface owns all drag/pinch
    // gestures; Flutter's TabBarView also has swipe navigation disabled.
    return FamilyConstellationView(
      key: widget.constellationKey,
      modalOpen: widget.suspendWebView,
      members: widget.members,
      relationships: widget.relationships,
      connections: widget.connections,
      events: widget.events,
      focusedMemberId: widget.focusedMemberId,
      onFocus: widget.onFocus,
      onAddPerson: widget.onAddPerson,
      onAddEvent: widget.onAddEvent,
      onEventDetails: widget.onEventTap,
      onAddAlbumForEvent: widget.onAddAlbumForEvent,
      onConnect: widget.onConnect,
      onAddRelative: widget.onAddRelative,
      onDetails: widget.onMemberTap,
    );
  }
}

class _PeopleTab extends StatelessWidget {
  const _PeopleTab({
    required this.members,
    required this.relationships,
    required this.connections,
    required this.events,
    required this.memories,
    required this.onAdd,
    required this.onTap,
  });

  final List<FamilyMember> members;
  final List<FamilyRelationship> relationships;
  final List<LifeConnection> connections;
  final List<LifeEvent> events;
  final List<FamilyMemory> memories;
  final VoidCallback onAdd;
  final ValueChanged<FamilyMember> onTap;

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return _ModuleEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No people yet',
        description: 'Add family, friends, colleagues, mentors and the important people in your life.',
        buttonLabel: 'Add person',
        onPressed: onAdd,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 112),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final member = members[index];
        final relationCount = relationships.where((relationship) =>
          relationship.fromMemberId == member.id || relationship.toMemberId == member.id).length;
        final socialCount = connections.where((connection) =>
          connection.fromMemberId == member.id || connection.toMemberId == member.id).length;
        final eventCount = events.where((event) => event.participantIds.contains(member.id)).length;
        final memoryCount = memories.where((memory) =>
            memory.linkedMemberIds.contains(member.id)).length;
        return AppSurface(
          onTap: () => onTap(member),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              _MemberAvatar(member: member, radius: 30),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (member.occupation.trim().isNotEmpty)
                      Text(member.occupation, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                      '${relationCount + socialCount} connections · $eventCount events · $memoryCount memories · ${member.imagePaths.length} photos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        );
      },
    );
  }
}

/// Photo-first albums with an optional library-wide photo grid. An image tap
/// opens the real fullscreen viewer; the album caption opens the detail page.
class _MemoriesTab extends StatefulWidget {
  const _MemoriesTab({required this.memories, required this.memberById,
    required this.onAdd, required this.onTap, required this.onPhotoTap,
    this.selectedMemoryId});

  final List<FamilyMemory> memories;
  final FamilyMember? Function(int?) memberById;
  final VoidCallback onAdd;
  final ValueChanged<FamilyMemory> onTap;
  final int? selectedMemoryId;
  final void Function(List<String> paths, int index, String title) onPhotoTap;

  @override
  State<_MemoriesTab> createState() => _MemoriesTabState();
}

typedef _ArchivePhotoEntry = ({FamilyMemory memory, String path, int index});

class _MemoriesTabState extends State<_MemoriesTab> {
  bool _showAllPhotos = false;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  String _sortBy = 'newest';
  List<FamilyMemory>? _lastMemories;
  List<_ArchivePhotoEntry> _cachedPhotos = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ArchivePhotoEntry> get _photos {
    // Filesystem checks run only on a refreshed album collection, not on every
    // palette change or Albums/Photos toggle.
    if (identical(_lastMemories, widget.memories)) return _cachedPhotos;
    final next = <_ArchivePhotoEntry>[];
    for (final memory in widget.memories) {
      final paths = memory.imagePaths;
      for (var index = 0; index < paths.length; index++) {
        if (LifeArchiveMedia.canDisplay(paths[index])) {
          next.add((memory: memory, path: paths[index], index: index));
        }
      }
    }
    _lastMemories = widget.memories;
    return _cachedPhotos = next;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.memories.isEmpty) return _ModuleEmptyState(
      icon: Icons.photo_library_outlined,
      title: 'Capture your first memory',
      description: 'Collect photos from an event or day, add a title and date, and tag everyone who was there.',
      buttonLabel: 'Create memory', onPressed: widget.onAdd,
    );

    final isDesktop = MediaQuery.sizeOf(context).width >= LifeArchiveDesktop.breakpoint;
    final query = _searchText.trim().toLowerCase();
    final visibleMemories = widget.memories.where((memory) => query.isEmpty ||
        memory.title.toLowerCase().contains(query) ||
        memory.description.toLowerCase().contains(query)).toList();
    visibleMemories.sort((a, b) => switch (_sortBy) {
      'oldest' => (a.memoryDate ?? DateTime(0)).compareTo(b.memoryDate ?? DateTime(0)),
      'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      _ => (b.memoryDate ?? DateTime(0)).compareTo(a.memoryDate ?? DateTime(0)),
    });
    final visibleIds = visibleMemories.map((memory) => memory.id).toSet();
    final photos = _photos.where((photo) => visibleIds.contains(photo.memory.id)).toList();
    final photoPaths = photos.map((entry) => entry.path).toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
          AppSpacing.lg, AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Memories gallery', style: Theme.of(context)
                    .textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${widget.memories.length} albums · ${photos.length} photos',
                  style: Theme.of(context).textTheme.bodySmall),
              ])),
            IconButton(tooltip: 'Create memory', onPressed: widget.onAdd,
              icon: const Icon(Icons.add_photo_alternate_outlined)),
          ]),
          const SizedBox(height: AppSpacing.md),
          if (isDesktop)
            Wrap(spacing: 12, runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(width: 300, child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchText = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search memories', isDense: true,
                    border: OutlineInputBorder(),
                  ),
                )),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest first')),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest first')),
                    DropdownMenuItem(value: 'title', child: Text('Title A–Z')),
                  ],
                  onChanged: (value) => setState(() => _sortBy = value ?? 'newest'),
                ),
              ]),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<bool>(value: false,
                label: Text('Albums'), icon: Icon(Icons.collections_outlined)),
              ButtonSegment<bool>(value: true,
                label: Text('Photos'), icon: Icon(Icons.grid_view_rounded)),
            ],
            selected: {_showAllPhotos},
            onSelectionChanged: (selected) => setState(() => _showAllPhotos = selected.first),
          ),
        ]),
      ),
      Expanded(child: (_showAllPhotos && photos.isEmpty) ||
          (!_showAllPhotos && visibleMemories.isEmpty)
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.hide_image_outlined, size: 55, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(query.isNotEmpty ? 'No memories match your search.'
              : 'No album photos yet.'),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(onPressed: widget.onAdd,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add photos to a memory')),
          ]))
        : LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1100 ? 5 : width >= 850 ? 4
                : width >= 575 ? 3 : 2;
            final isPhotos = _showAllPhotos;
            return GridView.builder(
              key: PageStorageKey<String>(isPhotos ? 'life-photos' : 'life-albums'),
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs,
                AppSpacing.md, 112),
              itemCount: isPhotos ? photos.length : visibleMemories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10, mainAxisSpacing: 10,
                childAspectRatio: isPhotos ? 1 : (isDesktop ? .89 : .70),
              ),
              itemBuilder: (context, index) {
                if (isPhotos) {
                  final photo = photos[index];
                  return Semantics(
                    label: 'View ${photo.memory.title} photo ${photo.index + 1} full screen',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Material(color: scheme.surfaceContainerLow,
                        child: InkWell(
                          onTap: () => widget.onPhotoTap(
                            photoPaths, index, 'Life Archive photos'),
                          child: Stack(fit: StackFit.expand, children: [
                            LifeArchiveMedia.image(photo.path, fit: BoxFit.cover,
                              cacheWidth: 650,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                            Positioned(left: 0, right: 0, bottom: 0,
                              child: DecoratedBox(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black87])),
                                child: Padding(padding: const EdgeInsets.fromLTRB(8, 20, 8, 9),
                                  child: Text(photo.memory.title,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white,
                                      fontSize: 12, fontWeight: FontWeight.w600))),
                              )),
                          ]),
                        ),
                      ),
                    ),
                  );
                }
                final memory = visibleMemories[index];
                final member = widget.memberById(memory.memberId);
                final valid = memory.imagePaths.where((p) => LifeArchiveMedia.canDisplay(p)).toList();
                return Material(
                  clipBehavior: Clip.antiAlias,
                  color: scheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color: widget.selectedMemoryId == memory.id
                          ? scheme.primary : scheme.outlineVariant,
                      width: widget.selectedMemoryId == memory.id ? 2 : 1)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: InkWell(
                      // An album opens its gallery/detail view, never a slider.
                      onTap: () => widget.onTap(memory),
                      child: Stack(fit: StackFit.expand, children: [
                        if (valid.isEmpty)
                          Center(child: Icon(Icons.auto_stories_outlined,
                              size: 46, color: scheme.primary))
                        else LifeArchiveMedia.image(valid.first, fit: BoxFit.cover,
                          cacheWidth: 650,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined))),
                        if (valid.isNotEmpty) Positioned(right: 8, top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                            child: Padding(padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.photo_library_outlined,
                                  color: Colors.white, size: 13),
                                const SizedBox(width: 4),
                                Text('${valid.length}', style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                              ])),
                          )),
                      ]),
                    )),
                    InkWell(
                      onTap: () => widget.onTap(memory),
                      child: Padding(padding: const EdgeInsets.fromLTRB(10, 9, 10, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(memory.title, maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(memory.memoryDate != null
                              ? DateFormat.yMMMd().format(memory.memoryDate!)
                              : (member?.fullName ?? 'View memory'),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                        ]),
                      ),
                    ),
                  ]),
                );
              },
            );
          }),
      ),
    ]);
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, required this.radius});

  final FamilyMember member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = member.profileImagePath;
    final exists = path != null && LifeArchiveMedia.canDisplay(path);
    return CircleAvatar(
      radius: radius,
      backgroundImage: exists ? LifeArchiveMedia.provider(path!)! : null,
      child: exists ? null : Icon(Icons.person_outline_rounded, size: radius),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value == 'Not set') return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
    );
  }
}

class _ModuleEmptyState extends StatelessWidget {
  const _ModuleEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;

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
              Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.add_rounded), label: Text(buttonLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
