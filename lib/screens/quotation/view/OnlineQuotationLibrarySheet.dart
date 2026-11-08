import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../controller/quotation_controller.dart';
import '../services/quotation_online_service.dart';
import '../services/quotation_service.dart';

class OnlineQuotationLibrarySheet extends ConsumerStatefulWidget {
  const OnlineQuotationLibrarySheet({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  ConsumerState<OnlineQuotationLibrarySheet> createState() =>
      _OnlineQuotationLibrarySheetState();
}

class _OnlineQuotationLibrarySheetState
    extends ConsumerState<OnlineQuotationLibrarySheet> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = <String>{};

  OnlineQuotationCatalog? _catalog;
  Map<String, int> _installedCounts = const {};
  bool _isLoading = true;
  bool _isDownloading = false;
  String? _error;
  int _completedDownloads = 0;
  int _totalDownloads = 0;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        ref.read(quotationOnlineServiceProvider).fetchCatalog(),
        ref.read(quotationServiceProvider).getOnlineCategoryCounts(),
      ]);

      if (!mounted) return;
      setState(() {
        _catalog = results[0] as OnlineQuotationCatalog;
        _installedCounts = results[1] as Map<String, int>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  List<OnlineQuotationCategory> get _visibleCategories {
    final catalog = _catalog;
    if (catalog == null) return const [];

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return catalog.categories;

    return catalog.categories
        .where(
          (category) =>
              category.name.toLowerCase().contains(query) ||
              category.id.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  void _selectMissing() {
    final catalog = _catalog;
    if (catalog == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(
          catalog.categories
              .where(
                (category) =>
                    (_installedCounts[category.id] ?? 0) < category.count,
              )
              .map((category) => category.id),
        );
    });
  }

  void _selectInstalled() {
    final catalog = _catalog;
    if (catalog == null) return;
    setState(() {
      _selected
        ..clear()
        ..addAll(
          catalog.categories
              .where((category) => (_installedCounts[category.id] ?? 0) > 0)
              .map((category) => category.id),
        );
    });
  }

  Future<void> _downloadSelected() async {
    final catalog = _catalog;
    if (catalog == null || _selected.isEmpty || _isDownloading) return;

    final categories = catalog.categories
        .where((category) => _selected.contains(category.id))
        .toList(growable: false);

    setState(() {
      _isDownloading = true;
      _completedDownloads = 0;
      _totalDownloads = categories.length;
      _error = null;
    });

    var summary = const QuotationImportResult();

    try {
      final onlineService = ref.read(quotationOnlineServiceProvider);
      final localService = ref.read(quotationServiceProvider);

      for (final category in categories) {
        final quotations = await onlineService.fetchCategory(category);
        final result = await localService.importOnlineCategory(
          categoryId: category.id,
          categoryName: category.name,
          catalogVersion: catalog.contentVersion,
          quotations: quotations,
        );
        summary = summary + result;

        if (!mounted) return;
        setState(() => _completedDownloads++);
      }

      await ref.read(quotationControllerProvider.notifier).refresh();
      final counts =
          await ref.read(quotationServiceProvider).getOnlineCategoryCounts();

      if (!mounted) return;
      setState(() {
        _installedCounts = counts;
        _selected.clear();
        _isDownloading = false;
      });

      _showMessage(
        'Online library updated: ${summary.inserted} added, '
        '${summary.updated} updated, ${summary.skipped} already current.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _removeCategory(OnlineQuotationCategory category) async {
    final installed = _installedCounts[category.id] ?? 0;
    if (installed == 0 || _isDownloading) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Remove ${category.name}?'),
            content: Text(
              'This removes $installed downloaded quotation'
              '${installed == 1 ? '' : 's'} from this category. '
              'You can download them again at any time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final removed = await ref
        .read(quotationServiceProvider)
        .removeOnlineCategory(category.id);
    await ref.read(quotationControllerProvider.notifier).refresh();

    if (!mounted) return;
    final counts =
        await ref.read(quotationServiceProvider).getOnlineCategoryCounts();
    setState(() => _installedCounts = counts);
    _showMessage('$removed downloaded quotations removed.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final catalog = _catalog;

    return SizedBox(
      height: widget.embedded
          ? double.infinity
          : MediaQuery.sizeOf(context).height * .90,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.habit.withOpacity(.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.cloud_download_outlined,
                    color: AppColors.habit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online quotation library',
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        catalog == null
                            ? 'GitHub quotation repository'
                            : '${catalog.totalQuotations} quotes • '
                                '${catalog.totalCategories} categories • '
                                'v${catalog.contentVersion}',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh catalog',
                  onPressed: _isDownloading ? null : _loadCatalog,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: widget.embedded ? 'Back to quotations' : 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    widget.embedded ? Icons.arrow_back_rounded : Icons.close,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: neutral.divider),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && catalog == null)
            Expanded(
              child: _OnlineErrorState(
                message: _error!,
                onRetry: _loadCatalog,
              ),
            )
          else if (catalog != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                enabled: !_isDownloading,
                decoration: InputDecoration(
                  hintText: 'Search online categories',
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
                  filled: true,
                  fillColor: neutral.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 17),
                    label: const Text('Select missing'),
                    onPressed: _isDownloading ? null : _selectMissing,
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.sync, size: 17),
                    label: const Text('Sync installed'),
                    onPressed: _isDownloading ? null : _selectInstalled,
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Clear'),
                    onPressed: _isDownloading
                        ? null
                        : () => setState(_selected.clear),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: Theme.of(context)
                      .colorScheme
                      .errorContainer
                      .withOpacity(.75),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!)),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                itemCount: _visibleCategories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final category = _visibleCategories[index];
                  final installed = _installedCounts[category.id] ?? 0;
                  final isComplete =
                      installed >= category.count && category.count > 0;
                  final selected = _selected.contains(category.id);

                  return Material(
                    color: selected
                        ? AppColors.habit.withOpacity(.08)
                        : neutral.card,
                    borderRadius: BorderRadius.circular(14),
                    child: CheckboxListTile(
                      value: selected,
                      onChanged: _isDownloading
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true) {
                                  _selected.add(category.id);
                                } else {
                                  _selected.remove(category.id);
                                }
                              });
                            },
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        installed == 0
                            ? '${category.count} available • Not downloaded'
                            : '$installed/${category.count} downloaded'
                                '${isComplete ? ' • Ready offline' : ''}',
                      ),
                      secondary: installed == 0
                          ? null
                          : PopupMenuButton<String>(
                              tooltip: 'Category actions',
                              onSelected: (value) {
                                if (value == 'remove') {
                                  _removeCategory(category);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Remove downloaded'),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _selected.isEmpty || _isDownloading
                            ? null
                            : _downloadSelected,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.habit,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    icon: _isDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      _isDownloading
                          ? 'Downloading $_completedDownloads/$_totalDownloads'
                          : _selected.isEmpty
                              ? 'Select categories to download'
                              : 'Download / sync ${_selected.length} '
                                  'categor${_selected.length == 1 ? 'y' : 'ies'}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnlineErrorState extends StatelessWidget {
  const _OnlineErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 46),
            const SizedBox(height: 14),
            const Text(
              'Could not load online quotations',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
