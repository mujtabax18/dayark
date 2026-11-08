part of '../scanner_desktop_dashboard.dart';

enum _ScannerDesktopSection { library, favorites, document }

class _ScannerDesktopDashboardState
    extends ConsumerState<ScannerDesktopDashboard> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<_ScannerDesktopSection> _rootSection =
      ValueNotifier<_ScannerDesktopSection>(_ScannerDesktopSection.library);

  _ScannerDesktopSection _selectedSection = _ScannerDesktopSection.library;
  int? _selectedGroupId;
  int _navigationToken = 0;
  bool _managementBusy = false;

  @override
  void dispose() {
    _rootSection.dispose();
    super.dispose();
  }

  void _returnToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  void _selectRoot(_ScannerDesktopSection section) {
    _navigationToken++;
    _returnToRoot();
    _rootSection.value = section;
    setState(() {
      _selectedSection = section;
      _selectedGroupId = null;
    });
  }

  void _openGroup(int groupId) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    final token = ++_navigationToken;
    _returnToRoot();
    setState(() {
      _selectedSection = _ScannerDesktopSection.document;
      _selectedGroupId = groupId;
    });

    navigator
        .push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/scanner-desktop/group/$groupId'),
            builder: (_) => ScanGroupViewScreen(groupId: groupId),
          ),
        )
        .then((_) {
          if (!mounted || token != _navigationToken) return;
          _selectRoot(_ScannerDesktopSection.library);
          _refreshGroups();
        });
  }

  Future<void> _backupScanner() async {
    if (_managementBusy) return;
    setState(() => _managementBusy = true);
    try {
      final db = await ref.read(databaseServiceProvider).database;
      final password = await BackupPasswordDialog.create(context);
        if (password == null || !mounted) return;
        final result = await BackupService.backupDocumentScannerToZip(db, password: password);
      if (!mounted) return;
      _showMessage(result.message);
    } catch (error) {
      if (mounted) _showMessage('Scanner backup failed: $error');
    } finally {
      if (mounted) setState(() => _managementBusy = false);
    }
  }

  Future<void> _restoreScanner() async {
    if (_managementBusy) return;
    setState(() => _managementBusy = true);
    try {
      final result = await DatabaseRestoreService.openFileExtractData(context: context);
      await _refreshGroups();
      if (!mounted) return;

      if (result?.startsWith('success:') == true) {
        final parts = result!.split(':');
        if (parts.length >= 3) {
          _showMessage(
            'Restore complete: ${parts[1]} file(s) restored, ${parts[2]} skipped.',
          );
          return;
        }
      }
      _showMessage(result ?? 'Restore cancelled.');
    } catch (error) {
      if (mounted) _showMessage('Scanner restore failed: $error');
    } finally {
      if (mounted) setState(() => _managementBusy = false);
    }
  }

  Future<void> _refreshGroups() async {
    ref.invalidate(scanGroupPreviewProvider);
    ref.invalidate(filteredScanGroupPreviewProvider);
    try {
      await ref.read(scanGroupPreviewProvider.future);
    } catch (_) {
      // The gallery will render the provider error with its normal retry flow.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(scanGroupPreviewProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surface,
      child: Row(
        children: [
          _ScannerModuleSidebar(
            groupsAsync: groupsAsync,
            selectedSection: _selectedSection,
            selectedGroupId: _selectedGroupId,
            busy: _managementBusy,
            onLibrary: () => _selectRoot(_ScannerDesktopSection.library),
            onFavorites: () => _selectRoot(_ScannerDesktopSection.favorites),
            onDocument: _openGroup,
            onBackup: _backupScanner,
            onRestore: _restoreScanner,
            onBackToDashboard: () {
              final desktopScope = DesktopNavigationScope.maybeOf(context);
              if (desktopScope != null) {
                desktopScope.onDashboard();
              } else if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: .72),
          ),
          Expanded(
            child: ClipRect(
              child: Navigator(
                key: _navigatorKey,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/scanner-desktop'),
                  builder: (_) =>
                      ValueListenableBuilder<_ScannerDesktopSection>(
                    valueListenable: _rootSection,
                    builder: (context, section, __) => ScannerGalleryScreen(
                      key: ValueKey('scanner-gallery-$section'),
                      desktopEmbedded: true,
                      initialFavoritesOnly:
                          section == _ScannerDesktopSection.favorites,
                      onOpenGroup: _openGroup,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerModuleSidebar extends StatelessWidget {
  const _ScannerModuleSidebar({
    required this.groupsAsync,
    required this.selectedSection,
    required this.selectedGroupId,
    required this.busy,
    required this.onLibrary,
    required this.onFavorites,
    required this.onDocument,
    required this.onBackup,
    required this.onRestore,
    required this.onBackToDashboard,
  });

  final AsyncValue<List<ScanGroupPreview>> groupsAsync;
  final _ScannerDesktopSection selectedSection;
  final int? selectedGroupId;
  final bool busy;
  final VoidCallback onLibrary;
  final VoidCallback onFavorites;
  final ValueChanged<int> onDocument;
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onBackToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groups = groupsAsync.asData?.value ?? const <ScanGroupPreview>[];
    final favorites = groups.where((group) => group.isFavorite).length;
    final recent = [...groups]
      ..sort((a, b) {
        final aDate = DateTime.tryParse(
              a.updatedAt.isEmpty ? a.createdAt : a.updatedAt,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(
              b.updatedAt.isEmpty ? b.createdAt : b.updatedAt,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return SizedBox(
      width: 278,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.document_scanner_outlined,
                      color: scheme.onPrimaryContainer,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Documents',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${groups.length} saved document${groups.length == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.phone_android_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Camera scanning is mobile only. Desktop is for viewing and managing documents already in your library.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SidebarLabel(text: 'LIBRARY'),
              const SizedBox(height: 5),
              _SidebarItem(
                icon: Icons.folder_copy_outlined,
                label: 'All documents',
                badge: '${groups.length}',
                selected: selectedSection == _ScannerDesktopSection.library,
                onTap: onLibrary,
              ),
              _SidebarItem(
                icon: Icons.star_outline_rounded,
                label: 'Favorites',
                badge: '$favorites',
                selected: selectedSection == _ScannerDesktopSection.favorites,
                onTap: onFavorites,
              ),
              const SizedBox(height: 12),
              const _SidebarLabel(text: 'MANAGE'),
              const SizedBox(height: 5),
              _SidebarItem(
                icon: Icons.backup_outlined,
                label: 'Backup scanner',
                selected: false,
                enabled: !busy,
                onTap: onBackup,
              ),
              _SidebarItem(
                icon: Icons.restore_rounded,
                label: 'Restore backup',
                selected: false,
                enabled: !busy,
                onTap: onRestore,
              ),
              const SizedBox(height: 12),
              const _SidebarLabel(text: 'RECENT DOCUMENTS'),
              const SizedBox(height: 6),
              Expanded(
                child: groupsAsync.when(
                  loading: () => const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Could not load documents.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ),
                  data: (_) => recent.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            'Scans created on mobile will appear here after they are available on this device.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: recent.length > 10 ? 10 : recent.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 3),
                          itemBuilder: (context, index) {
                            final group = recent[index];
                            return _RecentDocumentItem(
                              group: group,
                              selected: selectedSection ==
                                      _ScannerDesktopSection.document &&
                                  selectedGroupId == group.id,
                              onTap: () => onDocument(group.id),
                            );
                          },
                        ),
                ),
              ),
              Divider(color: scheme.outlineVariant.withValues(alpha: .7)),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: onBackToDashboard,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to dashboard'),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
      ),
    );
  }
}

