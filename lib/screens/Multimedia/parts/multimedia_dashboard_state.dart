part of '../MultimediaDashboard.dart';

class _MultimediaDashboardState extends ConsumerState<MultimediaDashboard> {
  final TextEditingController _searchController = TextEditingController();

  _MediaHomeView _homeView = _MediaHomeView.collections;
  String _selectedType = 'all';
  bool _favoritesOnly = false;
  int? _selectedCollectionId;
  bool _isImporting = false;
  late Future<MediaLinkedOverview> _linkedOverview;

  Widget? _desktopDetail;
  int _desktopDetailSerial = 0;

  bool get _isDesktopLayout =>
      MediaQueryData.fromView(View.of(context)).size.width >= 1100;

  MediaQuery get _query => MediaQuery(
    type: _selectedType,
    search: _searchController.text,
    favoritesOnly: _favoritesOnly,
    collectionId: _selectedCollectionId,
  );

  @override
  void initState() {
    super.initState();
    _linkedOverview = _fetchLinkedOverview();
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialAction) {
          case 'image':
            _pickImage(ImageSource.gallery, openEditor: true);
            break;
          case 'video':
            _pickSingleAndEdit('video');
            break;
          case 'pdf':
            _pickSingleAndEdit('pdf');
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(filteredMediaListProvider(_query));
    final statsAsync = ref.watch(mediaStatsProvider);
    final collectionsAsync = ref.watch(mediaCollectionsProvider);

    if (_isDesktopLayout) {
      return _buildDesktop(mediaAsync, statsAsync, collectionsAsync);
    }
    return _buildMobile(mediaAsync, statsAsync, collectionsAsync);
  }

  Widget _buildMobile(
    AsyncValue<List<MediaFile>> mediaAsync,
    AsyncValue<dynamic> statsAsync,
    AsyncValue<List<MediaCollection>> collectionsAsync,
  ) {
    final neutral = context.themeColors.neutral;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: BackButton(color: neutral.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline Media Studio',
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Originals, edits and history stay on this device',
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Offline text to speech',
            onPressed: () => _openTool(const OfflineTtsScreen()),
            icon: Icon(
              Icons.record_voice_over_outlined,
              color: neutral.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Backup and restore',
            onPressed: () => _openTool(const MediaBackupRestoreScreen()),
            icon: Icon(
              Icons.settings_backup_restore,
              color: neutral.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshMediaLibrary(ref);
          _refreshLinkedOverview();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildStatsCard(statsAsync),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: _ViewModeToggle(
                        value: _homeView,
                        onChanged: _setHomeView,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Manage collections',
                      onPressed: _showCollectionsManager,
                      icon: const Icon(Icons.folder_copy_outlined),
                    ),
                  ],
                ),
              ),
            ),
            if (_homeView == _MediaHomeView.collections) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: _linkedLibrariesHome(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Collections',
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Browse your media like albums in a phone gallery.',
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _createCollection,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('New'),
                      ),
                    ],
                  ),
                ),
              ),
              _buildCollectionGridSliver(collectionsAsync),
            ] else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _buildSearchField(),
                ),
              ),
              SliverToBoxAdapter(child: _buildFilters()),
              _buildMediaGridSliver(mediaAsync, desktop: false),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _isImporting ? null : _showImportActions,
        icon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add),
        label: Text(_isImporting ? 'Importing…' : 'Add media'),
      ),
    );
  }

  Widget _buildDesktop(
    AsyncValue<List<MediaFile>> mediaAsync,
    AsyncValue<dynamic> statsAsync,
    AsyncValue<List<MediaCollection>> collectionsAsync,
  ) {
    final neutral = context.themeColors.neutral;

    return Scaffold(
      backgroundColor: neutral.background,
      body: Row(
        children: [
          SizedBox(width: 242, child: _buildDesktopSidebar(collectionsAsync)),
          VerticalDivider(width: 1, thickness: 1, color: neutral.divider),
          Expanded(
            child: _desktopDetail != null
                ? _EmbeddedDesktopNavigator(
                    key: ValueKey(_desktopDetailSerial),
                    detail: _desktopDetail!,
                    onClose: _closeDesktopDetail,
                  )
                : Column(
                    children: [
                      _buildDesktopHeader(collectionsAsync),
                      Divider(height: 1, thickness: 1, color: neutral.divider),
                      Expanded(
                        child: _homeView == _MediaHomeView.collections
                            ? _buildDesktopCollectionsHome(
                                statsAsync,
                                collectionsAsync,
                              )
                            : _buildDesktopLibrary(mediaAsync, statsAsync),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(
    AsyncValue<List<MediaCollection>> collectionsAsync,
  ) {
    final neutral = context.themeColors.neutral;

    return ColoredBox(
      color: neutral.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.perm_media_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Media Studio',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          'Offline library',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isImporting ? null : _showImportActions,
                icon: _isImporting
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(_isImporting ? 'Importing…' : 'Add media'),
              ),
            ),
            const SizedBox(height: 18),
            _DesktopSectionLabel(label: 'BROWSE'),
            _DesktopMediaNavItem(
              icon: Icons.photo_library_outlined,
              label: 'Collections',
              selected: _homeView == _MediaHomeView.collections,
              onTap: _showCollectionsHome,
            ),
            _DesktopMediaNavItem(
              icon: Icons.grid_view_rounded,
              label: 'All media',
              selected:
                  _homeView == _MediaHomeView.library &&
                  _selectedCollectionId == null &&
                  _selectedType == 'all' &&
                  !_favoritesOnly,
              onTap: _showAllMedia,
            ),
            _DesktopMediaNavItem(
              icon: Icons.star_outline_rounded,
              label: 'Favorites',
              selected: _homeView == _MediaHomeView.library && _favoritesOnly,
              onTap: _showFavorites,
            ),
            _DesktopMediaNavItem(
              icon: Icons.image_outlined,
              label: 'Images',
              selected:
                  _homeView == _MediaHomeView.library &&
                  _selectedCollectionId == null &&
                  _selectedType == 'image' &&
                  !_favoritesOnly,
              onTap: () => _showMediaType('image'),
            ),
            _DesktopMediaNavItem(
              icon: Icons.movie_outlined,
              label: 'Videos',
              selected:
                  _homeView == _MediaHomeView.library &&
                  _selectedCollectionId == null &&
                  _selectedType == 'video' &&
                  !_favoritesOnly,
              onTap: () => _showMediaType('video'),
            ),
            _DesktopMediaNavItem(
              icon: Icons.graphic_eq_rounded,
              label: 'Audio',
              selected:
                  _homeView == _MediaHomeView.library &&
                  _selectedCollectionId == null &&
                  _selectedType == 'audio' &&
                  !_favoritesOnly,
              onTap: () => _showMediaType('audio'),
            ),
            _DesktopMediaNavItem(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF files',
              selected:
                  _homeView == _MediaHomeView.library &&
                  _selectedCollectionId == null &&
                  _selectedType == 'pdf' &&
                  !_favoritesOnly,
              onTap: () => _showMediaType('pdf'),
            ),
            const SizedBox(height: 12),
            const _DesktopSectionLabel(label: 'CONNECTED LIBRARIES'),
            _DesktopMediaNavItem(
              icon: Icons.photo_album_outlined,
              label: 'Memory albums',
              selected: false,
              onTap: () => _browseLinked(MediaLinkedSection.memories),
            ),
            _DesktopMediaNavItem(
              icon: Icons.document_scanner_outlined,
              label: 'Scanned documents',
              selected: false,
              onTap: () => _browseLinked(MediaLinkedSection.documents),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: _DesktopSectionLabel(label: 'COLLECTIONS'),
                ),
                IconButton(
                  tooltip: 'New collection',
                  visualDensity: VisualDensity.compact,
                  onPressed: _createCollection,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            Expanded(
              child: collectionsAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => Center(
                  child: Text(
                    'Collections unavailable',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                data: (collections) {
                  if (collections.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Create a collection to organize related media.',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: collections.length,
                    itemBuilder: (context, index) {
                      final collection = collections[index];
                      return _DesktopMediaNavItem(
                        icon: Icons.folder_outlined,
                        label: collection.name,
                        count: collection.itemCount,
                        selected:
                            _homeView == _MediaHomeView.library &&
                            _selectedCollectionId == collection.id,
                        onTap: () => _openCollection(collection),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _DesktopMediaNavItem(
              icon: Icons.delete_outline,
              label: 'Trash',
              selected: false,
              onTap: _showTrash,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(
    AsyncValue<List<MediaCollection>> collectionsAsync,
  ) {
    final neutral = context.themeColors.neutral;
    final collections =
        collectionsAsync.asData?.value ?? const <MediaCollection>[];
    MediaCollection? selectedCollection;
    for (final collection in collections) {
      if (collection.id == _selectedCollectionId) {
        selectedCollection = collection;
        break;
      }
    }

    final title = _homeView == _MediaHomeView.collections
        ? 'Collections'
        : selectedCollection?.name ??
              (_favoritesOnly
                  ? 'Favorites'
                  : _selectedType == 'all'
                  ? 'All media'
                  : '${_typeLabel(_selectedType)} media');

    return LayoutBuilder(
      builder: (context, constraints) {
        final showViewToggle = constraints.maxWidth >= 760;
        return Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: neutral.background,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _homeView == _MediaHomeView.collections
                          ? 'Album-style organization for your offline media library'
                          : 'Browse, edit and organize without leaving the desktop workspace',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showViewToggle) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 230,
                  child: _ViewModeToggle(
                    value: _homeView,
                    onChanged: _setHomeView,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Offline text to speech',
                onPressed: () => _openTool(const OfflineTtsScreen()),
                icon: const Icon(Icons.record_voice_over_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Backup and restore',
                onPressed: () => _openTool(const MediaBackupRestoreScreen()),
                icon: const Icon(Icons.settings_backup_restore),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopCollectionsHome(
    AsyncValue<dynamic> statsAsync,
    AsyncValue<List<MediaCollection>> collectionsAsync,
  ) {
    final neutral = context.themeColors.neutral;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: _buildDesktopStats(statsAsync),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
            child: _linkedLibrariesHome(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your collections',
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Open an album to see its media. One item can belong to multiple collections.',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _showCollectionsManager,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Manage'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _createCollection,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('New collection'),
                ),
              ],
            ),
          ),
        ),
        _buildCollectionGridSliver(collectionsAsync, desktop: true),
      ],
    );
  }

  Widget _buildDesktopLibrary(
    AsyncValue<List<MediaFile>> mediaAsync,
    AsyncValue<dynamic> statsAsync,
  ) {
    return RefreshIndicator(
      onRefresh: () async => refreshMediaLibrary(ref),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: _buildDesktopStats(statsAsync),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isImporting ? null : _showImportActions,
                    icon: const Icon(Icons.add),
                    label: const Text('Add media'),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildFilters(desktop: true),
            ),
          ),
          _buildMediaGridSliver(mediaAsync, desktop: true),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final neutral = context.themeColors.neutral;
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search title, type or extension',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: neutral.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: neutral.divider),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildStatsCard(AsyncValue<dynamic> statsAsync) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: statsAsync.when(
        loading: () => const SizedBox(
          height: 46,
          child: Center(child: LinearProgressIndicator()),
        ),
        error: (_, __) => Text(
          'Library statistics unavailable',
          style: TextStyle(color: neutral.textSecondary),
        ),
        data: (stats) => Row(
          children: [
            _StatItem(label: 'All', value: '${stats.total}'),
            _StatItem(label: 'Images', value: '${stats.images}'),
            _StatItem(label: 'Video', value: '${stats.videos}'),
            _StatItem(label: 'Audio', value: '${stats.audio}'),
            _StatItem(label: 'PDF', value: '${stats.pdfs}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopStats(AsyncValue<dynamic> statsAsync) {
    final neutral = context.themeColors.neutral;
    return statsAsync.when(
      loading: () => const SizedBox(
        height: 82,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, __) => Container(
        height: 76,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: neutral.divider),
        ),
        child: Text(
          'Library statistics unavailable',
          style: TextStyle(color: neutral.textSecondary),
        ),
      ),
      data: (stats) {
        final values = <(String, String, IconData)>[
          ('All media', '${stats.total}', Icons.perm_media_outlined),
          ('Images', '${stats.images}', Icons.image_outlined),
          ('Videos', '${stats.videos}', Icons.movie_outlined),
          ('Audio', '${stats.audio}', Icons.graphic_eq_rounded),
          ('PDF files', '${stats.pdfs}', Icons.picture_as_pdf_outlined),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 10.0;
            final columns = constraints.maxWidth >= 980
                ? 5
                : constraints.maxWidth >= 650
                ? 3
                : 2;
            final cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final item in values)
                  SizedBox(
                    width: cardWidth,
                    child: _DesktopStatCard(
                      label: item.$1,
                      value: item.$2,
                      icon: item.$3,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilters({bool desktop = false}) {
    final neutral = context.themeColors.neutral;
    final collectionsAsync = ref.watch(mediaCollectionsProvider);
    MediaCollection? selectedCollection;
    final collections =
        collectionsAsync.asData?.value ?? const <MediaCollection>[];
    for (final collection in collections) {
      if (collection.id == _selectedCollectionId) {
        selectedCollection = collection;
        break;
      }
    }

    const filters = <(String, String, IconData)>[
      ('all', 'All', Icons.grid_view_rounded),
      ('image', 'Images', Icons.image_outlined),
      ('video', 'Video', Icons.movie_outlined),
      ('audio', 'Audio', Icons.graphic_eq),
      ('pdf', 'PDF', Icons.picture_as_pdf_outlined),
    ];

    return SizedBox(
      height: 52,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: desktop ? 16 : 16,
          vertical: 5,
        ),
        scrollDirection: Axis.horizontal,
        children: [
          OutlinedButton.icon(
            onPressed: _showCollectionsManager,
            icon: const Icon(Icons.folder_copy_outlined, size: 18),
            label: Text(
              selectedCollection == null
                  ? 'Collections'
                  : selectedCollection.name,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _selectedCollectionId == null
                  ? neutral.textSecondary
                  : AppColors.primary,
            ),
          ),
          if (_selectedCollectionId != null) ...[
            const SizedBox(width: 6),
            IconButton.outlined(
              tooltip: 'Show all media',
              visualDensity: VisualDensity.compact,
              onPressed: _showAllMedia,
              icon: const Icon(Icons.close, size: 17),
            ),
          ],
          const SizedBox(width: 8),
          ...filters.map((filter) {
            final selected = _selectedType == filter.$1 && !_favoritesOnly;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                avatar: Icon(filter.$3, size: 17),
                label: Text(filter.$2),
                onSelected: (_) => setState(() {
                  _homeView = _MediaHomeView.library;
                  _selectedType = filter.$1;
                  _favoritesOnly = false;
                }),
              ),
            );
          }),
          ChoiceChip(
            selected: _favoritesOnly,
            avatar: const Icon(Icons.star_outline, size: 17),
            label: const Text('Favorites'),
            onSelected: (_) => setState(() {
              _homeView = _MediaHomeView.library;
              _selectedType = 'all';
              _favoritesOnly = !_favoritesOnly;
            }),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _showTrash,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Trash'),
            style: OutlinedButton.styleFrom(
              foregroundColor: neutral.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionGridSliver(
    AsyncValue<List<MediaCollection>> collectionsAsync, {
    bool desktop = false,
  }) {
    return collectionsAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: _MessageState(
          icon: Icons.error_outline,
          title: 'Could not load collections',
          message: error.toString(),
        ),
      ),
      data: (collections) {
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 24 : 16,
            8,
            desktop ? 24 : 16,
            desktop ? 32 : 110,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final count = desktop
                  ? width >= 1200
                        ? 5
                        : width >= 900
                        ? 4
                        : width >= 620
                        ? 3
                        : 2
                  : width >= 760
                  ? 4
                  : width >= 520
                  ? 3
                  : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: desktop ? 16 : 12,
                  mainAxisSpacing: desktop ? 16 : 12,
                  childAspectRatio: desktop ? 1.05 : .92,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return _SystemCollectionCard(onOpen: _showAllMedia);
                  }
                  if (index == collections.length + 1) {
                    return _CreateCollectionCard(onCreate: _createCollection);
                  }
                  final collection = collections[index - 1];
                  return _CollectionGalleryCard(
                    collection: collection,
                    onOpen: () => _openCollection(collection),
                    onRename: () => _renameCollection(collection),
                    onDelete: () => _deleteCollection(collection),
                  );
                }, childCount: collections.length + 2),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMediaGridSliver(
    AsyncValue<List<MediaFile>> mediaAsync, {
    required bool desktop,
  }) {
    return mediaAsync.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: _MessageState(
          icon: Icons.error_outline,
          title: 'Could not load the media library',
          message: error.toString(),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _MessageState(
              icon: _selectedCollectionId == null
                  ? Icons.perm_media_outlined
                  : Icons.folder_open_outlined,
              title: _selectedCollectionId == null
                  ? 'No media found'
                  : 'This collection is empty',
              message: _selectedCollectionId == null
                  ? 'Import images, video, audio or PDF files. Every imported original is preserved.'
                  : 'Use the folder button on a media card to add it to this collection.',
            ),
          );
        }
        return SliverPadding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 24 : 16,
            8,
            desktop ? 24 : 16,
            desktop ? 32 : 100,
          ),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final count = desktop
                  ? width >= 1300
                        ? 6
                        : width >= 1000
                        ? 5
                        : width >= 760
                        ? 4
                        : width >= 540
                        ? 3
                        : 2
                  : width >= 760
                  ? 4
                  : width >= 520
                  ? 3
                  : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: desktop ? 14 : 12,
                  mainAxisSpacing: desktop ? 14 : 12,
                  childAspectRatio: desktop ? .86 : .79,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _MediaCard(
                    media: items[index],
                    onOpen: () => _openMedia(items[index]),
                    onFavorite: () => _toggleFavorite(items[index]),
                    onCollections: () => _showCollectionPicker(items[index]),
                    onTrash: () => _moveToTrash(items[index]),
                  ),
                  childCount: items.length,
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _setHomeView(_MediaHomeView view) {
    if (view == _homeView) return;
    setState(() {
      _homeView = view;
      if (view == _MediaHomeView.collections) {
        _selectedCollectionId = null;
        _favoritesOnly = false;
        _selectedType = 'all';
        _searchController.clear();
      }
    });
  }

  void _showCollectionsHome() {
    setState(() {
      _homeView = _MediaHomeView.collections;
      _selectedCollectionId = null;
      _favoritesOnly = false;
      _selectedType = 'all';
      _searchController.clear();
    });
  }

  void _showAllMedia() {
    setState(() {
      _homeView = _MediaHomeView.library;
      _selectedCollectionId = null;
      _favoritesOnly = false;
      _selectedType = 'all';
    });
  }

  void _showFavorites() {
    setState(() {
      _homeView = _MediaHomeView.library;
      _selectedCollectionId = null;
      _favoritesOnly = true;
      _selectedType = 'all';
    });
  }

  void _showMediaType(String type) {
    setState(() {
      _homeView = _MediaHomeView.library;
      _selectedCollectionId = null;
      _favoritesOnly = false;
      _selectedType = type;
    });
  }

  void _openCollection(MediaCollection collection) {
    if (collection.id == null) return;
    setState(() {
      _homeView = _MediaHomeView.library;
      _selectedCollectionId = collection.id;
      _selectedType = 'all';
      _favoritesOnly = false;
      _searchController.clear();
    });
  }

  String _typeLabel(String type) {
    return switch (type) {
      'image' => 'Image',
      'video' => 'Video',
      'audio' => 'Audio',
      'pdf' => 'PDF',
      _ => 'All',
    };
  }

  Future<MediaLinkedOverview> _fetchLinkedOverview() =>
      MediaLinkedLibrariesService(ref.read(scanGroupServiceProvider)).load();

  void _refreshLinkedOverview() {
    if (!mounted) return;
    setState(() => _linkedOverview = _fetchLinkedOverview());
  }

  Future<void> _browseLinked(MediaLinkedSection section) async {
    await _openTool<void>(MediaLinkedLibrariesScreen(initialSection: section));
    if (mounted && !_isDesktopLayout) _refreshLinkedOverview();
  }

  Future<void> _openLinkedAlbum(LinkedMemoryAlbum album) async {
    // Full width is important for the existing desktop inspector and gallery.
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => FamilyTreeDetailScreen(
          treeId: album.archive.id,
          initialTabIndex: 2,
          initialMemoryId: album.memory.id,
        ),
      ),
    );
    if (mounted) _refreshLinkedOverview();
  }

  Future<void> _openLinkedDocument(ScanGroupPreview document) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => ScanGroupViewScreen(groupId: document.id),
      ),
    );
    if (mounted) _refreshLinkedOverview();
  }

  Widget _linkedLibrariesHome() => MediaLinkedOverviewSection(
    overview: _linkedOverview,
    onBrowseMemories: () => _browseLinked(MediaLinkedSection.memories),
    onBrowseDocuments: () => _browseLinked(MediaLinkedSection.documents),
    onOpenAlbum: _openLinkedAlbum,
    onOpenDocument: _openLinkedDocument,
  );

  void _openDesktopDetail(Widget child) {
    setState(() {
      _desktopDetail = child;
      _desktopDetailSerial++;
    });
  }

  void _closeDesktopDetail() {
    if (!mounted || _desktopDetail == null) return;
    setState(() => _desktopDetail = null);
    refreshMediaLibrary(ref);
    _refreshLinkedOverview();
  }

  Future<T?> _openTool<T>(Widget screen) async {
    if (_isDesktopLayout) {
      _openDesktopDetail(screen);
      return null;
    }
    final result = await Navigator.of(context)
        .push<T>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) refreshMediaLibrary(ref);
    return result;
  }

  Future<void> _showImportActions() async {
    final neutral = context.themeColors.neutral;

    Widget content(BuildContext actionContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ImportActionTile(
          icon: Icons.photo_library_outlined,
          title: 'Choose image and edit',
          subtitle: 'The untouched original is saved first',
          onTap: () {
            Navigator.pop(actionContext);
            _pickImage(ImageSource.gallery, openEditor: true);
          },
        ),
        _ImportActionTile(
          icon: Icons.camera_alt_outlined,
          title: 'Take photo and edit',
          onTap: () {
            Navigator.pop(actionContext);
            _pickImage(ImageSource.camera, openEditor: true);
          },
        ),
        _ImportActionTile(
          icon: Icons.video_settings_outlined,
          title: 'Choose video and edit',
          subtitle: 'Trim, speed, reverse, mute and transform',
          onTap: () {
            Navigator.pop(actionContext);
            _pickSingleAndEdit('video');
          },
        ),
        _ImportActionTile(
          icon: Icons.edit_document,
          title: 'Choose PDF and edit',
          subtitle: 'Annotate, sign, search, reorder and save',
          onTap: () {
            Navigator.pop(actionContext);
            _pickSingleAndEdit('pdf');
          },
        ),
        _ImportActionTile(
          icon: Icons.library_add_outlined,
          title: 'Import multiple files',
          subtitle: 'Images, video, audio and PDF',
          onTap: () {
            Navigator.pop(actionContext);
            _pickMultipleFiles();
          },
        ),
        _ImportActionTile(
          icon: Icons.record_voice_over_outlined,
          title: 'Create speech audio',
          subtitle: 'Uses the offline voice installed on device',
          onTap: () {
            Navigator.pop(actionContext);
            _openTool(const OfflineTtsScreen());
          },
        ),
      ],
    );

    if (_isDesktopLayout) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: neutral.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add media',
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose what you want to import or create.',
                    style: TextStyle(color: neutral.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  content(dialogContext),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: neutral.card,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: content(sheetContext),
        ),
      ),
    );
  }

  Future<void> _pickImage(
    ImageSource source, {
    required bool openEditor,
  }) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 100,
      );
      if (picked == null) return;

      setState(() => _isImporting = true);
      final media = await ref
          .read(mediaServiceProvider)
          .importFile(File(picked.path));
      await _addImportedToSelectedCollection([media]);
      refreshMediaLibrary(ref);
      if (!mounted) return;

      if (openEditor) {
        await _openImageEditor(media);
      }
    } catch (error) {
      _showError('Could not import image: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _pickSingleAndEdit(String type) async {
    try {
      final extensions = type == 'video'
          ? const ['mp4', 'mov', 'mkv', 'webm', 'avi']
          : const ['pdf'];
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      final path = result?.first.path;
      if (path == null) return;

      setState(() => _isImporting = true);
      final media = await ref.read(mediaServiceProvider).importFile(File(path));
      await _addImportedToSelectedCollection([media]);
      refreshMediaLibrary(ref);
      if (!mounted) return;

      if (type == 'video') {
        await _openTool<MediaFile>(VideoEditorScreen(media: media));
      } else {
        await _openTool<MediaFile>(MediaPdfEditorScreen(media: media));
      }
      if (mounted) refreshMediaLibrary(ref);
    } catch (error) {
      if (mounted) _showError('Could not open editor: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _pickMultipleFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'bmp',
          'heic',
          'mp4',
          'mov',
          'mkv',
          'webm',
          'avi',
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'flac',
          'caf',
          'pdf',
        ],
      );
      if (result == null) return;
      final files = result
          .where((file) => file.path != null)
          .map((file) => File(file.path!))
          .toList();

      if (files.isEmpty) return;

      setState(() => _isImporting = true);
      final imported = await ref.read(mediaServiceProvider).importFiles(files);
      await _addImportedToSelectedCollection(imported);
      refreshMediaLibrary(ref);
      if (mounted) {
        _showMessage('${imported.length} file(s) imported safely.');
      }
    } catch (error) {
      _showError('Import failed: $error');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _addImportedToSelectedCollection(
    Iterable<MediaFile> mediaItems,
  ) async {
    final collectionId = _selectedCollectionId;
    if (collectionId == null) return;
    final service = ref.read(mediaServiceProvider);
    for (final media in mediaItems) {
      final mediaId = media.id;
      if (mediaId == null) continue;
      await service.setMediaInCollection(
        mediaId: mediaId,
        collectionId: collectionId,
        included: true,
      );
    }
  }

  Future<void> _openImageEditor(MediaFile media) async {
    final source = File(media.currentPath);
    if (!await source.exists()) {
      _showError(
        'The image file is missing. Restore a ZIP backup to recover it.',
      );
      return;
    }

    if (_isDesktopLayout) {
      _openDesktopDetail(
        Builder(
          builder: (editorContext) => ProImageEditor.file(
            source,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (bytes) async {
                final saved = await ref
                    .read(mediaServiceProvider)
                    .saveEditedVersion(
                      media: media,
                      bytes: bytes,
                      action: 'image_edit',
                      metadata: {'editor': 'pro_image_editor'},
                    );
                refreshMediaLibrary(ref);
                if (mounted) {
                  _showMessage(
                    'Version ${saved.version} saved. Original kept unchanged.',
                  );
                }
                if (editorContext.mounted) {
                  Navigator.of(editorContext).pop(saved);
                }
              },
            ),
          ),
        ),
      );
      return;
    }

    final updated = await Navigator.of(context).push<MediaFile>(
      MaterialPageRoute(
        builder: (editorContext) => ProImageEditor.file(
          source,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              final saved = await ref
                  .read(mediaServiceProvider)
                  .saveEditedVersion(
                    media: media,
                    bytes: bytes,
                    action: 'image_edit',
                    metadata: {'editor': 'pro_image_editor'},
                  );
              if (editorContext.mounted) {
                Navigator.of(editorContext).pop(saved);
              }
            },
          ),
        ),
      ),
    );

    if (updated != null && mounted) {
      refreshMediaLibrary(ref);
      _showMessage(
        'Version ${updated.version} saved. Original kept unchanged.',
      );
    }
  }

  Future<void> _openMedia(MediaFile media) async {
    await _openTool(MediaViewerScreen(mediaFile: media));
    if (mounted) refreshMediaLibrary(ref);
  }

  Future<void> _toggleFavorite(MediaFile media) async {
    await ref.read(mediaServiceProvider).toggleFavorite(media);
    refreshMediaLibrary(ref);
  }

  Future<void> _moveToTrash(MediaFile media) async {
    await ref.read(mediaServiceProvider).moveToTrash(media);
    refreshMediaLibrary(ref);
    if (mounted) _showMessage('Moved to trash. Files are still recoverable.');
  }

  Future<void> _createCollection() async {
    final name = await _promptForCollectionName(context);
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref.read(mediaServiceProvider).createCollection(name);
      refreshMediaLibrary(ref);
      if (mounted) _showMessage('Collection created.');
    } catch (error) {
      if (mounted) _showError('Could not create collection: $error');
    }
  }

  Future<void> _renameCollection(MediaCollection collection) async {
    if (collection.id == null) return;
    final name = await _promptForCollectionName(
      context,
      initialValue: collection.name,
      title: 'Rename collection',
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await ref
          .read(mediaServiceProvider)
          .renameCollection(collection.id!, name);
      refreshMediaLibrary(ref);
    } catch (error) {
      if (mounted) _showError('Could not rename collection: $error');
    }
  }

  Future<void> _deleteCollection(MediaCollection collection) async {
    if (collection.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete “${collection.name}”?'),
        content: const Text(
          'The collection will be removed, but its media files will stay in the library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(mediaServiceProvider).deleteCollection(collection.id!);
      if (_selectedCollectionId == collection.id && mounted) {
        setState(() {
          _selectedCollectionId = null;
          _homeView = _MediaHomeView.collections;
        });
      }
      refreshMediaLibrary(ref);
    } catch (error) {
      if (mounted) _showError('Could not delete collection: $error');
    }
  }

  Future<void> _showCollectionsManager() async {
    final Future<int?> selection;
    if (_isDesktopLayout) {
      selection = showDialog<int>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: _MediaCollectionsSheet(
              selectedCollectionId: _selectedCollectionId,
            ),
          ),
        ),
      );
    } else {
      selection = showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) =>
            _MediaCollectionsSheet(selectedCollectionId: _selectedCollectionId),
      );
    }

    final selected = await selection;
    if (!mounted) return;
    refreshMediaLibrary(ref);
    if (selected != null) {
      if (selected < 0) {
        _showAllMedia();
      } else {
        setState(() {
          _homeView = _MediaHomeView.library;
          _selectedCollectionId = selected;
          _selectedType = 'all';
          _favoritesOnly = false;
        });
      }
      return;
    }

    if (_selectedCollectionId != null) {
      final collections = await ref.read(mediaServiceProvider).getCollections();
      if (!collections.any((item) => item.id == _selectedCollectionId) &&
          mounted) {
        setState(() {
          _selectedCollectionId = null;
          _homeView = _MediaHomeView.collections;
        });
      }
    }
  }

  Future<void> _showCollectionPicker(MediaFile media) async {
    if (media.id == null) return;
    if (_isDesktopLayout) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _MediaCollectionPicker(media: media),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _MediaCollectionPicker(media: media),
      );
    }
    if (mounted) refreshMediaLibrary(ref);
  }

  Future<void> _showTrash() async {
    await _openTool(const _MediaTrashScreen());
    if (mounted) refreshMediaLibrary(ref);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }
}
