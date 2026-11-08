part of '../scanner_gallery_screen.dart';

class _ScannerGalleryScreenState extends ConsumerState<ScannerGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sort = 'updated';
  late bool _favoritesOnly;
  bool _gridView = true;
  bool _busy = false;
  String? _status;

  ScanGroupQuery get _query => ScanGroupQuery(
    search: _searchController.text,
    favoritesOnly: _favoritesOnly,
    sort: _sort,
  );

  @override
  void initState() {
    super.initState();
    _favoritesOnly = widget.initialFavoritesOnly;
    if (widget.startWithCamera && documentScannerCaptureSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scanAndSave();
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
    final groupsAsync = ref.watch(filteredScanGroupPreviewProvider(_query));
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.desktopEmbedded,
        title: Text(
          widget.desktopEmbedded ? 'Document library' : 'Document Scanner',
        ),
        actions: [
          IconButton(
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
          ),
          if (!widget.desktopEmbedded)
            PopupMenuButton<String>(
              onSelected: _handleAppMenu,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'backup',
                  child: ListTile(
                    leading: Icon(Icons.backup_outlined),
                    title: Text('Backup scanner'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'restore',
                  child: ListTile(
                    leading: Icon(Icons.restore),
                    title: Text('Restore scanner backup'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: DesktopContentFrame(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(groupsAsync)),
              groupsAsync.when(
                loading: () => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load scans',
                    message: error.toString(),
                  ),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                        icon: Icons.document_scanner_outlined,
                        title: 'No scanned documents',
                        message: documentScannerCaptureSupported
                            ? 'Scan with the camera or import existing images. All files stay offline.'
                            : 'Desktop mode is for viewing and managing existing scanned documents. Use the mobile app to scan new documents.',
                      ),
                    );
                  }
                  if (_gridView) return _buildGrid(groups);
                  return _buildList(groups);
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: documentScannerCaptureSupported
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _showAddActions,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add document'),
            )
          : null,
    );
  }

  Widget _buildHeader(AsyncValue<List<ScanGroupPreview>> groupsAsync) {
    final groups = groupsAsync.asData?.value ?? const <ScanGroupPreview>[];
    final pages = groups.fold<int>(0, (sum, group) => sum + group.pageCount);
    final bytes = groups.fold<int>(0, (sum, group) => sum + group.totalBytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Documents',
                  value: '${groups.length}',
                  icon: Icons.folder_copy_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Pages',
                  value: '$pages',
                  icon: Icons.layers_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Storage',
                  value: _formatBytes(bytes),
                  icon: Icons.sd_storage_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search title, tags, notes or OCR text',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilterChip(
                selected: _favoritesOnly,
                avatar: const Icon(Icons.star_outline, size: 18),
                label: const Text('Favorites'),
                onSelected: (value) => setState(() => _favoritesOnly = value),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sort,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'updated',
                      child: Text('Recently updated'),
                    ),
                    DropdownMenuItem(
                      value: 'name',
                      child: Text('Document name'),
                    ),
                    DropdownMenuItem(value: 'pages', child: Text('Most pages')),
                    DropdownMenuItem(
                      value: 'oldest',
                      child: Text('Oldest first'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sort = value);
                  },
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Text(
                _status!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrid(List<ScanGroupPreview> groups) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.crossAxisExtent >= 900
              ? 5
              : constraints.crossAxisExtent >= 620
              ? 3
              : 2;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, index) => _DocumentCard(
                group: groups[index],
                onOpen: () => _openGroup(groups[index]),
                onFavorite: () => _toggleFavorite(groups[index]),
                onDelete: () => _deleteGroup(groups[index]),
              ),
              childCount: groups.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(List<ScanGroupPreview> groups) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      sliver: SliverList.separated(
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final group = groups[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => _openGroup(group),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.square(
                  dimension: 56,
                  child: _ScanThumbnail(path: group.thumbnailPath),
                ),
              ),
              title: Text(
                group.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${group.pageCount} page(s) • ${_formatBytes(group.totalBytes)}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'favorite') _toggleFavorite(group);
                  if (value == 'delete') _deleteGroup(group);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'favorite',
                    child: Text(
                      group.isFavorite ? 'Remove favorite' : 'Favorite',
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddActions() async {
    if (!documentScannerCaptureSupported) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Scan with camera'),
              subtitle: const Text(
                'Automatic edge detection and multi-page capture',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _scanAndSave();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Import image pages'),
              subtitle: const Text(
                'Select multiple JPG, PNG, WebP or BMP files',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _importImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAndSave() async {
    if (!documentScannerCaptureSupported) return;
    final granted = await ScanPermissionService.requestCamera();
    if (!granted) {
      if (!mounted) return;
      _showPermissionDialog();
      return;
    }
    await _run(() async {
      final paths = await CunningDocumentScanner.getPictures(
        isGalleryImportAllowed: true,
      );
      if (paths == null || paths.isEmpty) return 'Scanning cancelled.';
      final groupId = await ref
          .read(scannerControllerProvider.notifier)
          .addMultipleScans(paths: paths, source: 'camera');
      await _refresh();
      if (groupId != null && mounted) {
        final openGroup = widget.onOpenGroup;
        if (openGroup != null) {
          openGroup(groupId);
        } else {
          context.push('/scanner/group', extra: groupId);
        }
      }
      return '${paths.length} page(s) saved in managed offline storage.';
    });
  }

  Future<void> _importImages() async {
    await _run(() async {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );
      if (result == null) return 'Import cancelled.';
      final paths = result.whereType<String>().toList(growable: false);
      if (paths.isEmpty) return 'No usable image was selected.';
      await ref
          .read(scannerControllerProvider.notifier)
          .addMultipleScans(paths: paths, source: 'file_import');
      await _refresh();
      return '${paths.length} image page(s) imported.';
    });
  }

  Future<void> _handleAppMenu(String value) async {
    if (value == 'backup') {
      await _run(() async {
        final db = await ref.read(databaseServiceProvider).database;
        final password = await BackupPasswordDialog.create(context);
        if (password == null || !mounted) return 'Backup cancelled.';
        final result = await BackupService.backupDocumentScannerToZip(db, password: password);
        return result.message;
      });
    } else if (value == 'restore') {
      await _run(() async {
        final result = await DatabaseRestoreService.openFileExtractData(context: context);
        await _refresh();
        if (result?.startsWith('success:') == true) {
          final parts = result!.split(':');
          return 'Restore complete: ${parts[1]} file(s) restored, ${parts[2]} skipped.';
        }
        return result ?? 'No result returned.';
      });
    }
  }

  Future<void> _toggleFavorite(ScanGroupPreview group) async {
    await ref.read(scanGroupServiceProvider).toggleFavorite(group.id);
    await _refresh();
  }

  Future<void> _deleteGroup(ScanGroupPreview group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '“${group.title}” and its ${group.pageCount} page image(s) will be permanently deleted from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(scanGroupServiceProvider).deleteGroupWithScans(group.id);
    await _refresh();
  }

  Future<void> _openGroup(ScanGroupPreview group) async {
    final openGroup = widget.onOpenGroup;
    if (openGroup != null) {
      openGroup(group.id);
    } else {
      await context.push('/scanner/group', extra: group.id);
    }
    if (mounted) await _refresh();
  }

  Future<void> _refresh() async {
    ref.invalidate(scanGroupPreviewProvider);
    ref.invalidate(filteredScanGroupPreviewProvider);
    await ref.read(filteredScanGroupPreviewProvider(_query).future);
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _status = message);
    } catch (error) {
      if (mounted) setState(() => _status = 'Operation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showPermissionDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera permission required'),
        content: const Text(
          'Allow camera access to scan paper documents. You can still import existing image files without camera permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScanPermissionService.openSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

