part of '../family_tree_detail_screen.dart';

class _FamilyTreeDetailScreenState extends State<FamilyTreeDetailScreen>
    with SingleTickerProviderStateMixin {
  final FamilyTreeRepository _repository = FamilyTreeRepository();
  final LifeArchiveRepository _lifeRepository = LifeArchiveRepository();
  late final TabController _tabController;

  bool _loading = true;
  bool _refreshing = false;
  FamilyTree? _tree;
  List<FamilyMember> _members = const [];
  List<FamilyRelationship> _relationships = const [];
  List<FamilyMemory> _memories = const [];
  List<LifeConnection> _connections = const [];
  List<LifeEvent> _events = const [];
  int? _focusedMemberId;
  // A Media Studio deep link opens one of the existing memory albums.
  bool _initialMemoryHandled = false;

  // Desktop inspector uses stable IDs so it refreshes after edits without
  // pushing another route or losing scroll/filter position in the workspace.
  int? _inspectorMemoryId;
  int? _inspectorEventId;
  int? _inspectorTabIndex;
  bool _inspectorGraphSuspended = false;
  final List<({int? memoryId, int? eventId})> _inspectorHistory = [];
  bool get _hasInspector =>
      _inspectorMemoryId != null || _inspectorEventId != null;

  // Native Linux/Windows WebViews can be composited above Flutter's navigator.
  // Swap the native surface for a preview while a Flutter sheet is visible.
  final GlobalKey<FamilyConstellationViewState> _constellationKey =
      GlobalKey<FamilyConstellationViewState>();
  int _familyModalDepth = 0;
  bool _constellationSuspended = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3).toInt(),
    );
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {
        if (_inspectorTabIndex != null &&
            _inspectorTabIndex != _tabController.index) {
          _resetInspectorSelection();
        }
      });
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_refreshing) return;
    if (!_loading && mounted) setState(() => _refreshing = true);
    try {
      final results = await Future.wait<Object?>([
        _repository.getTree(widget.treeId),
        _repository.getMembers(widget.treeId),
        _repository.getRelationships(widget.treeId),
        _repository.getMemories(widget.treeId),
        _lifeRepository.getConnections(widget.treeId),
        _lifeRepository.getEvents(widget.treeId),
      ]);
      if (!mounted) return;
      setState(() {
        _tree = results[0] as FamilyTree?;
        _members = results[1] as List<FamilyMember>;
        if (_focusedMemberId == null && _members.isNotEmpty) {
          _focusedMemberId = _members
              .map((person) => person.id)
              .reduce((a, b) => a < b ? a : b);
        }
        if (_focusedMemberId != null &&
            !_members.any((person) => person.id == _focusedMemberId) &&
            _members.isNotEmpty) {
          _focusedMemberId = _members.first.id;
        }
        _relationships = results[2] as List<FamilyRelationship>;
        _memories = results[3] as List<FamilyMemory>;
        _connections = results[4] as List<LifeConnection>;
        _events = results[5] as List<LifeEvent>;
        // The detail panel always uses the latest model from the repository.
        // Close it when a selected record was removed externally.
        if (_inspectorMemoryId != null &&
            !_memories.any((item) => item.id == _inspectorMemoryId)) {
          _resetInspectorSelection();
        }
        if (_inspectorEventId != null &&
            !_events.any((item) => item.id == _inspectorEventId)) {
          _resetInspectorSelection();
        }
      });
      // Do not duplicate the Media library: open the memory within its owner
      // archive so its photo gallery, related events, edit/delete all still work.
      if (!_initialMemoryHandled && widget.initialMemoryId != null) {
        _initialMemoryHandled = true;
        final matches = _memories.where((item) =>
            item.id == widget.initialMemoryId);
        if (matches.isNotEmpty) {
          final memory = matches.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showMemoryDetails(memory);
          });
        }
      }
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _refreshing = false;
        });
    }
  }

  /// Quick relationships need only graph data, not the (unmodified) memories.
  /// Keep the old graph visible during the refresh instead of flashing a
  /// full-screen spinner and recreating the canvas.
  Future<void> _refreshConnections() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final results = await Future.wait<Object?>([
        _repository.getMembers(widget.treeId),
        _repository.getRelationships(widget.treeId),
        _lifeRepository.getConnections(widget.treeId),
        _lifeRepository.getEvents(widget.treeId),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<FamilyMember>;
        _relationships = results[1] as List<FamilyRelationship>;
        _connections = results[2] as List<LifeConnection>;
        _events = results[3] as List<LifeEvent>;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _resetInspectorSelection() {
    _inspectorMemoryId = null;
    _inspectorEventId = null;
    _inspectorTabIndex = null;
    _inspectorHistory.clear();
    if (_inspectorGraphSuspended) {
      _inspectorGraphSuspended = false;
      if (_familyModalDepth == 0) _constellationSuspended = false;
    }
  }

  void _closeInspector() {
    if (!mounted || !_hasInspector) return;
    setState(_resetInspectorSelection);
  }

  Future<void> _selectInspector({
    int? memoryId,
    int? eventId,
    bool followLink = false,
  }) async {
    if (!mounted || ((memoryId == null) == (eventId == null))) return;
    // The native graph is replaced with its snapshot only when the selection
    // is made from Network. This prevents desktop WebViews from painting above
    // the inspector on Linux/Windows (including at narrower window widths).
    if (_tabController.index == 0 && !_inspectorGraphSuspended) {
      if (_constellationKey.currentState != null) {
        await _constellationKey.currentState!.prepareForModal();
      }
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() {
      if (followLink && _hasInspector) {
        _inspectorHistory.add((
          memoryId: _inspectorMemoryId,
          eventId: _inspectorEventId,
        ));
      } else {
        _inspectorHistory.clear();
      }
      _inspectorMemoryId = memoryId;
      _inspectorEventId = eventId;
      _inspectorTabIndex = _tabController.index;
      if (_inspectorTabIndex == 0) {
        _inspectorGraphSuspended = true;
        _constellationSuspended = true;
      }
    });
  }

  void _backInspector() {
    if (_inspectorHistory.isEmpty || !mounted) {
      _closeInspector();
      return;
    }
    final previous = _inspectorHistory.removeLast();
    setState(() {
      _inspectorMemoryId = previous.memoryId;
      _inspectorEventId = previous.eventId;
    });
  }

  FamilyMember? _memberById(int? id) {
    if (id == null) return null;
    for (final member in _members) {
      if (member.id == id) return member;
    }
    return null;
  }

  /// Full-page previews share the native WebView suspension used by forms.
  Future<T?> _showArchivePage<T>(WidgetBuilder builder) async {
    _familyModalDepth++;
    try {
      if (_familyModalDepth == 1 && _constellationKey.currentState != null) {
        await _constellationKey.currentState!.prepareForModal();
        if (!mounted) return null;
        setState(() => _constellationSuspended = true);
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return null;
      return await Navigator.of(context, rootNavigator: true).push<T>(
        MaterialPageRoute<T>(builder: builder),
      );
    } finally {
      _familyModalDepth--;
      if (_familyModalDepth == 0 &&
          mounted &&
          _constellationSuspended &&
          !_inspectorGraphSuspended) {
        setState(() => _constellationSuspended = false);
      }
    }
  }

  /// Keeps native WebViews from appearing in front of Flutter bottom sheets.
  /// For the first sheet we capture the current camera's canvas, remove the
  /// native surface, and wait for Flutter to paint before pushing the route.
  /// Nested sheets (Details -> Edit / Add relative) share the same suspension.
  Future<T?> _showFamilyModal<T>({
    required WidgetBuilder builder,
    bool showDragHandle = false,
  }) async {
    _familyModalDepth++;
    try {
      if (_familyModalDepth == 1 && _constellationKey.currentState != null) {
        await _constellationKey.currentState!.prepareForModal();
        if (!mounted) return null;
        setState(() => _constellationSuspended = true);
        // Prevent the GTK/WebView2 surface from covering the incoming route.
        await WidgetsBinding.instance.endOfFrame;
      }
      if (!mounted) return null;
      return await showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: showDragHandle,
        // Inherit the same global theme as every other DayArk screen.
        builder: builder,
      );
    } finally {
      _familyModalDepth--;
      if (_familyModalDepth == 0 &&
          mounted &&
          _constellationSuspended &&
          !_inspectorGraphSuspended) {
        setState(() => _constellationSuspended = false);
      }
    }
  }

  Future<void> _showMemberForm([FamilyMember? member]) async {
    final changed = await _showFamilyModal<bool>(
      builder: (_) => FamilyMemberFormSheet(
        treeId: widget.treeId,
        repository: _repository,
        member: member,
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _quickAddRelative(FamilyMember member, String role) async {
    final addedId = await _showFamilyModal<int>(
      builder: (_) => FamilyQuickRelativeSheet(
        treeId: widget.treeId,
        anchor: member,
        members: _members,
        relationships: _relationships,
        repository: _repository,
        initialRole: role,
      ),
    );
    if (addedId == null || !mounted) return;
    // Maintain focus through reload. The newly added node becomes the next
    // center, allowing the family to grow in any direction.
    _focusedMemberId = addedId;
    await _refreshConnections();
  }

  Future<bool> _showMemoryForm({
    FamilyMemory? memory,
    int? initialMemberId,
    int? initialEventId,
  }) async {
    final changed = await _showFamilyModal<bool>(
      builder: (_) => FamilyMemoryFormSheet(
        treeId: widget.treeId,
        members: _members,
        events: _events,
        repository: _repository,
        memory: memory,
        initialEventId: initialEventId,
        initialMemberId: initialMemberId,
      ),
    );
    if (changed == true && mounted) await _load();
    return changed == true;
  }

  Future<void> _manageMemberPhotos(FamilyMember member) async {
    final changed = await _showFamilyModal<bool>(
      builder: (_) =>
          FamilyMemberPhotosSheet(member: member, repository: _repository),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _manageRelationships(FamilyMember member) async {
    await _showFamilyModal<bool>(
      builder: (_) => FamilyRelationshipSheet(
        treeId: widget.treeId,
        member: member,
        members: _members,
        relationships: _relationships,
        repository: _repository,
      ),
    );
    await _refreshConnections();
  }

  Future<void> _deleteMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete family member?'),
        content: Text(
          'This deletes ${member.fullName}, their relationships and memories linked only to them.',
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
    await _repository.deleteMember(member);
    if (mounted) Navigator.of(context).pop();
    await _load();
  }

  Future<bool> _deleteMemory(FamilyMemory memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete memory?'),
        content: Text(
          'Permanently delete “${memory.title}” and its ${memory.imagePaths.length} locally stored photos?',
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
    if (confirmed != true) return false;
    try {
      await _repository.deleteMemory(memory);
      if (mounted) await _load();
      return true;
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete memory: $error')),
        );
      return false;
    }
  }

  Future<void> _showMemberDetails(FamilyMember member) async {
    final memberRelationships = _relationships
        .where(
          (relationship) =>
              relationship.fromMemberId == member.id ||
              relationship.toMemberId == member.id,
        )
        .toList();
    final socialConnections = _connections
        .where(
          (connection) =>
              connection.fromMemberId == member.id ||
              connection.toMemberId == member.id,
        )
        .toList();
    final memberEvents = _events
        .where((event) => event.participantIds.contains(member.id))
        .toList();
    final memberMemories = _memories
        .where((memory) => memory.linkedMemberIds.contains(member.id))
        .toList();

    await _showFamilyModal<void>(
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .5,
        maxChildSize: .96,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    member.fullName,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (member.imagePaths.isNotEmpty)
              FamilyPhotoGallery(paths: member.imagePaths, height: 220)
            else
              Center(child: _MemberAvatar(member: member, radius: 54)),
            if (member.nickname.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Text(
                  '“${member.nickname}”',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _focusedMemberId = member.id;
                      _tabController.index = 0;
                    });
                  },
                  icon: const Icon(Icons.center_focus_strong_outlined),
                  label: const Text('Show in tree'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _showMemberForm(member);
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _quickAddRelative(member, 'child');
                  },
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add relative'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _manageRelationships(member);
                  },
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Family ties'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _showLifeConnectionForm(anchor: member);
                  },
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Add connection'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _showLifeEventForm(initialPersonId: member.id);
                  },
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Add event'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _showMemoryForm(initialMemberId: member.id);
                  },
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Add album'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _manageMemberPhotos(member);
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text('Photos (${member.imagePaths.length})'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle(title: 'Details'),
            _InfoRow(
              icon: Icons.cake_outlined,
              label: 'Born',
              value: _formatDate(member.birthDate),
            ),
            if (member.deathDate != null)
              _InfoRow(
                icon: Icons.event_busy_outlined,
                label: 'Died',
                value: _formatDate(member.deathDate),
              ),
            _InfoRow(
              icon: Icons.work_outline_rounded,
              label: 'Occupation',
              value: member.occupation,
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: member.phone,
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: member.email,
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: member.address,
            ),
            if (member.description.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SectionTitle(title: 'Description / biography'),
              Text(member.description),
            ],
            if (member.notes.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _SectionTitle(title: 'Private notes'),
              Text(member.notes),
            ],
            const SizedBox(height: AppSpacing.lg),
            _SectionTitle(
              title: 'Relationships (${memberRelationships.length})',
            ),
            if (memberRelationships.isEmpty)
              const Text('No relationships added yet.')
            else
              ...memberRelationships.map((relationship) {
                final otherId = relationship.fromMemberId == member.id
                    ? relationship.toMemberId
                    : relationship.fromMemberId;
                final other = _memberById(otherId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: other == null
                      ? const CircleAvatar(child: Icon(Icons.person_outline))
                      : _MemberAvatar(member: other, radius: 20),
                  title: Text(other?.fullName ?? 'Unknown person'),
                  subtitle: Text(_relationshipLabel(member, relationship)),
                  trailing: const Icon(
                    Icons.center_focus_strong_outlined,
                    size: 18,
                  ),
                  onTap: other == null
                      ? null
                      : () {
                          Navigator.of(sheetContext).pop();
                          setState(() {
                            _focusedMemberId = other.id;
                            _tabController.index = 0;
                          });
                        },
                );
              }),
            const SizedBox(height: AppSpacing.md),
            _SectionTitle(
              title: 'Life connections (${socialConnections.length})',
            ),
            if (socialConnections.isEmpty)
              const Text('No friends or social connections linked yet.')
            else
              ...socialConnections.map((connection) {
                final otherId = connection.fromMemberId == member.id
                    ? connection.toMemberId
                    : connection.fromMemberId;
                final other = _memberById(otherId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.hub_outlined),
                  title: Text(other?.fullName ?? 'Unknown person'),
                  subtitle: Text(connection.displayLabel),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _showLifeConnectionForm(connection: connection);
                  },
                );
              }),
            const SizedBox(height: AppSpacing.md),
            _SectionTitle(title: 'Life events (${memberEvents.length})'),
            if (memberEvents.isEmpty)
              const Text('No life events linked to this person yet.')
            else
              ...memberEvents
                  .take(6)
                  .map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_outlined),
                      title: Text(event.title),
                      subtitle: Text(_formatDate(event.eventDate)),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showLifeEventDetails(event);
                      },
                    ),
                  ),
            const SizedBox(height: AppSpacing.md),
            _SectionTitle(title: 'Albums (${memberMemories.length})'),
            if (memberMemories.isEmpty)
              const Text('No albums tagged with this person yet.')
            else
              ...memberMemories
                  .take(5)
                  .map(
                    (memory) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.auto_stories_outlined),
                      title: Text(memory.title),
                      subtitle: Text(_formatDate(memory.memoryDate)),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showMemoryDetails(memory);
                      },
                    ),
                  ),
            const SizedBox(height: AppSpacing.xl),
            TextButton.icon(
              onPressed: () => _deleteMember(member),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete person'),
            ),
          ],
        ),
      ),
    );
  }

  String _relationshipLabel(
    FamilyMember member,
    FamilyRelationship relationship,
  ) {
    final isFrom = relationship.fromMemberId == member.id;
    switch (relationship.type) {
      case 'parent':
        return isFrom ? 'Parent' : 'Child';
      case 'guardian':
        return isFrom ? 'Guardian' : 'Guarded by';
      case 'spouse':
        return 'Spouse';
      case 'partner':
        return 'Partner';
      case 'sibling':
        return 'Sibling';
      default:
        return 'Relative';
    }
  }

  Future<void> _showMemoryDetails(FamilyMemory memory) async {
    if (MediaQuery.sizeOf(context).width >= LifeArchiveDesktop.breakpoint) {
      await _selectInspector(memoryId: memory.id);
      return;
    }
    final people = memory.linkedMemberIds
        .map(_memberById)
        .whereType<FamilyMember>()
        .toList();
    final events = _events.where((event) => event.id == memory.eventId);
    final event = events.isEmpty ? null : events.first;
    await _showArchivePage<void>(
      (pageContext) => LifeArchiveMemoryPage(
        memory: memory,
        people: people,
        event: event,
        onEventTap: event == null ? null : () => _showLifeEventDetails(event),
        onEdit: () async {
          final changed = await _showMemoryForm(memory: memory);
          if (changed && pageContext.mounted) Navigator.of(pageContext).pop();
        },
        onDelete: () async {
          final deleted = await _deleteMemory(memory);
          if (deleted && pageContext.mounted) Navigator.of(pageContext).pop();
        },
      ),
    );
  }

  /// The embedded desktop WebView must be suspended before a photo route.
  Future<void> _showArchivePhotos(
    List<String> paths,
    int index,
    String title,
  ) async {
    final valid = paths
        .where((path) => LifeArchiveMedia.canDisplay(path))
        .toList();
    if (valid.isEmpty) return;
    final selected = index >= 0 && index < paths.length
        ? paths[index]
        : valid.first;
    final initialIndex = valid.indexOf(selected);
    await _showArchivePage<void>(
      (_) => FullscreenFamilyPhoto(
        paths: valid,
        initialIndex: initialIndex < 0 ? 0 : initialIndex,
        title: title,
      ),
    );
  }

  String _formatDate(DateTime? date) =>
      date == null ? 'Not set' : DateFormat.yMMMd().format(date);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => LifeArchiveDesktop.enabled(constraints)
        ? _buildDesktop(context)
        : _buildMobile(context),
  );

  Widget _buildDesktop(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tree = _tree;
    final index = _tabController.index;
    final labels = ['Network', 'People', 'Memories', 'Events'];
    final descriptions = [
      'Explore the connections in your life.',
      'Manage the people connected to this archive.',
      'Browse albums and your full photo library.',
      'Manage your milestones and meaningful events.',
    ];
    final photoCount = _memories.fold<int>(
      0,
      (count, memory) => count + memory.imagePaths.length,
    );

    Widget content;
    switch (index) {
      case 0:
        content = _TreeTab(
          constellationKey: _constellationKey,
          suspendWebView: _constellationSuspended,
          members: _members,
          relationships: _relationships,
          connections: _connections,
          events: _events,
          focusedMemberId: _focusedMemberId,
          onFocus: (id) => setState(() => _focusedMemberId = id),
          onAddPerson: () => _showMemberForm(),
          onAddEvent: () => _showLifeEventForm(),
          onAddAlbumForEvent: (event) =>
              _showMemoryForm(initialEventId: event.id),
          onEventTap: _showLifeEventDetails,
          onConnect: (person) => _showLifeConnectionForm(anchor: person),
          onAddRelative: _quickAddRelative,
          onMemberTap: _showMemberDetails,
        );
        break;
      case 1:
        content = _PeopleTab(
          members: _members,
          relationships: _relationships,
          connections: _connections,
          events: _events,
          memories: _memories,
          onAdd: () => _showMemberForm(),
          onTap: _showMemberDetails,
        );
        break;
      case 2:
        content = _MemoriesTab(
          memories: _memories,
          memberById: _memberById,
          onAdd: () => _showMemoryForm(),
          onTap: _showMemoryDetails,
          selectedMemoryId: _inspectorMemoryId,
          onPhotoTap: _showArchivePhotos,
        );
        break;
      default:
        content = _LifeEventsTab(
          events: _events,
          onAdd: () => _showLifeEventForm(),
          selectedEventId: _inspectorEventId,
          onTap: _showLifeEventDetails,
        );
        break;
    }

    final actions = <Widget>[
      if (index != 0)
        FilledButton.icon(
          onPressed: index == 3
              ? () => _showLifeEventForm()
              : index == 2
              ? () => _showMemoryForm()
              : () => _showMemberForm(),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            index == 3
                ? 'New event'
                : index == 2
                ? 'New memory'
                : 'Add person',
          ),
        ),
    ];

    final selectedMemory = _memories
        .where((memory) => memory.id == _inspectorMemoryId)
        .firstOrNull;
    final selectedEvent = _events
        .where((event) => event.id == _inspectorEventId)
        .firstOrNull;
    final inspectorVisible = selectedMemory != null || selectedEvent != null;
    final inspectorPeople = selectedMemory != null
        ? selectedMemory.linkedMemberIds
              .map(_memberById)
              .whereType<FamilyMember>()
              .toList()
        : (selectedEvent?.participantIds ?? const <int>[])
              .map(_memberById)
              .whereType<FamilyMember>()
              .toList();
    final relatedEvent = selectedMemory == null
        ? null
        : _events
              .where((event) => event.id == selectedMemory.eventId)
              .firstOrNull;
    final relatedMemories = selectedEvent == null
        ? const <FamilyMemory>[]
        : _memories
              .where((memory) => memory.eventId == selectedEvent.id)
              .toList();

    final inspector = inspectorVisible
        ? LifeArchiveInspectorPanel(
            key: ValueKey(
              'inspector-${_inspectorMemoryId ?? 'e'}-${_inspectorEventId ?? 'm'}',
            ),
            memory: selectedMemory,
            event: selectedEvent,
            people: inspectorPeople,
            relatedMemories: relatedMemories,
            relatedEvent: relatedEvent,
            onClose: _closeInspector,
            onBack: _inspectorHistory.isEmpty ? null : _backInspector,
            onEdit: () async {
              if (selectedMemory != null) {
                await _showMemoryForm(memory: selectedMemory);
              } else if (selectedEvent != null) {
                await _showLifeEventForm(event: selectedEvent);
              }
            },
            onDelete: () async {
              if (selectedMemory != null) {
                final deleted = await _deleteMemory(selectedMemory);
                if (deleted) _closeInspector();
              } else if (selectedEvent != null) {
                final deleted = await _deleteLifeEvent(selectedEvent);
                if (deleted) _closeInspector();
              }
            },
            onAddMemory: () async {
              if (selectedEvent != null) {
                await _showMemoryForm(initialEventId: selectedEvent.id);
              }
            },
            onSelectMemory: (memory) =>
                _selectInspector(memoryId: memory.id, followLink: true),
            onSelectEvent: (event) =>
                _selectInspector(eventId: event.id, followLink: true),
            onSelectPerson: _showMemberDetails,
            onViewPhoto: _showArchivePhotos,
          )
        : null;

    // The archive workspace stays mounted while inspector records change.
    // This preserves gallery scroll positions, search fields and event filters.
    final workspace = Column(
      children: [
        ArchiveDesktopWorkspace(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          child: ArchiveDesktopHeader(
            breadcrumb:
                'Life Archives / ${tree?.name ?? 'Archive'} / ${labels[index]}',
            title: index == 0 ? (tree?.name ?? 'Life Archive') : labels[index],
            subtitle: descriptions[index],
            actions: actions,
          ),
        ),
        if (index != 0 && !_loading && tree != null)
          Visibility(
            visible: !inspectorVisible,
            maintainState: true,
            child: ArchiveDesktopWorkspace(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    childAspectRatio: columns == 4 ? 2.95 : 3.2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      ArchiveDesktopStat(
                        label: 'People',
                        value: '${_members.length}',
                        icon: Icons.people_outline,
                        onTap: () => _tabController.animateTo(1),
                      ),
                      ArchiveDesktopStat(
                        label: 'Memories',
                        value: '${_memories.length}',
                        icon: Icons.collections_outlined,
                        onTap: () => _tabController.animateTo(2),
                      ),
                      ArchiveDesktopStat(
                        label: 'Photos',
                        value: '$photoCount',
                        icon: Icons.image_outlined,
                        onTap: () => _tabController.animateTo(2),
                      ),
                      ArchiveDesktopStat(
                        label: 'Events',
                        value: '${_events.length}',
                        icon: Icons.event_outlined,
                        onTap: () => _tabController.animateTo(3),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (tree == null)
                const Center(
                  child: Text('This life archive is no longer available.'),
                )
              else if (index == 0)
                content
              else
                ArchiveDesktopWorkspace(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                  child: content,
                ),
              if (_refreshing && !_loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Row(
        children: [
          ArchiveDesktopSidebar(
            title: 'LIFE ARCHIVE',
            subtitle: tree?.name ?? 'Loading archive',
            items: const [
              ArchiveNavigationItem('Network', Icons.hub_outlined),
              ArchiveNavigationItem('People', Icons.people_outline_rounded),
              ArchiveNavigationItem('Memories', Icons.photo_library_outlined),
              ArchiveNavigationItem('Events', Icons.event_note_rounded),
            ],
            selectedIndex: index,
            onSelected: (tab) => _tabController.animateTo(tab),
            footer: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('All archives'),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final available = constraints.maxWidth;
                if (available >= 1030) {
                  // Keep Row/Expanded in the tree even with the inspector closed:
                  // scroll, filters, search fields and grid state stay mounted.
                  return Row(
                    children: [
                      Expanded(child: workspace),
                      if (inspector != null)
                        SizedBox(
                          width: available >= 1250 ? 490 : 445,
                          child: inspector,
                        ),
                    ],
                  );
                }
                // Narrow desktop/browser window: an in-page right-side inspector.
                // A fixed Stack structure preserves the underlying workspace state.
                final panelWidth = (available * .88)
                    .clamp(335.0, 465.0)
                    .toDouble();
                return Stack(
                  children: [
                    Positioned.fill(child: workspace),
                    if (inspector != null)
                      Positioned.fill(
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _closeInspector,
                                child: ColoredBox(
                                  color: Colors.black.withOpacity(.16),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: panelWidth,
                              child: Material(elevation: 16, child: inspector),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final tree = _tree;
    return Scaffold(
        appBar: AppBar(
          title: Text(tree?.name ?? 'Life Archive'),
          actions: [
            if (_tabController.index == 0 && tree != null)
              IconButton(
                tooltip: 'About this life archive',
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => _showFamilyModal<void>(
                  showDragHandle: true,
                  builder: (sheetContext) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tree.name,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${_members.length} people · ${_relationships.length + _connections.length} connections · ${_events.length} events',
                            ),
                            if (tree.description.trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Text(tree.description),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.hub_outlined), text: 'Network'),
              Tab(icon: Icon(Icons.people_outline_rounded), text: 'People'),
              Tab(icon: Icon(Icons.auto_stories_outlined), text: 'Memories'),
              Tab(icon: Icon(Icons.event_outlined), text: 'Events'),
            ],
          ),
        ),
        // Tree nodes and the canvas toolbar provide add actions. Do not float
        // another button over the draggable area, particularly on small phones.
        floatingActionButton: _tabController.index == 0
            ? null
            : FloatingActionButton.extended(
                onPressed: _tabController.index == 3
                    ? () => _showLifeEventForm()
                    : _tabController.index == 2
                    ? () => _showMemoryForm()
                    : () => _showMemberForm(),
                icon: Icon(
                  _tabController.index == 3
                      ? Icons.add_circle_outline_rounded
                      : _tabController.index == 2
                      ? Icons.add_photo_alternate_outlined
                      : Icons.person_add_alt_1_outlined,
                ),
                label: Text(
                  _tabController.index == 3
                      ? 'Add event'
                      : _tabController.index == 2
                      ? 'Add memory'
                      : 'Add person',
                ),
              ),
        // The interactive Tree tab must use the full available width (including
        // on desktop). Apply the desktop readability limit to list tabs only.
        body: Stack(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator())
                : tree == null
                ? const Center(
                    child: Text('This life archive is no longer available.'),
                  )
                : TabBarView(
                    controller: _tabController,
                    // Horizontal page swipes fight the tree's horizontal drag.
                    // Tabs remain accessible via the TabBar above.
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _TreeTab(
                        constellationKey: _constellationKey,
                        suspendWebView: _constellationSuspended,
                        members: _members,
                        relationships: _relationships,
                        connections: _connections,
                        events: _events,
                        focusedMemberId: _focusedMemberId,
                        onFocus: (id) => setState(() => _focusedMemberId = id),
                        onAddPerson: () => _showMemberForm(),
                        onAddEvent: () => _showLifeEventForm(),
                        onAddAlbumForEvent: (event) =>
                            _showMemoryForm(initialEventId: event.id),
                        onEventTap: _showLifeEventDetails,
                        onConnect: (person) =>
                            _showLifeConnectionForm(anchor: person),
                        onAddRelative: _quickAddRelative,
                        onMemberTap: _showMemberDetails,
                      ),
                      DesktopContentFrame(
                        child: _PeopleTab(
                          members: _members,
                          relationships: _relationships,
                          connections: _connections,
                          events: _events,
                          memories: _memories,
                          onAdd: () => _showMemberForm(),
                          onTap: _showMemberDetails,
                        ),
                      ),
                      DesktopContentFrame(
                        child: _MemoriesTab(
                          memories: _memories,
                          memberById: _memberById,
                          onAdd: () => _showMemoryForm(),
                          onTap: _showMemoryDetails,
                          onPhotoTap: _showArchivePhotos,
                        ),
                      ),
                      DesktopContentFrame(
                        child: _LifeEventsTab(
                          events: _events,
                          onAdd: () => _showLifeEventForm(),
                          onTap: _showLifeEventDetails,
                        ),
                      ),
                    ],
                  ),
            if (_refreshing && !_loading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Semantics(
                  label: 'Updating life network',
                  child: const LinearProgressIndicator(minHeight: 3),
                ),
              ),
          ],
        ),
    );
  }
}
