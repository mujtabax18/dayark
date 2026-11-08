import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_x.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../Settings/controller/backup_restore_Provider.dart';
import '../components/AddGroceryItemWidget.dart';
import '../components/AddGroceryTitleWidget.dart';
import '../controller/grocery_controller.dart';
import '../shared/grocery_catalog.dart';
import '../../../../core/widgets/common/centered_fa_icon.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';
part '../widgets/grocery_item_widgets.dart';
part '../widgets/grocery_item_sheet_widgets.dart';

class GroceryListPage extends ConsumerStatefulWidget {
  const GroceryListPage({
    super.key,
    required this.groceryId,
    this.desktopEmbedded = false,
  });

  final int groceryId;
  final bool desktopEmbedded;

  @override
  ConsumerState<GroceryListPage> createState() => _GroceryListPageState();
}

class _GroceryListPageState extends ConsumerState<GroceryListPage> {
  String _filter = 'all';

  Future<void> _refresh() async {
    ref.invalidate(groceryPlanProvider(widget.groceryId));
    ref.invalidate(groceryItemsProvider(widget.groceryId));
    ref.invalidate(groceryDashboardProvider);
    ref.invalidate(groceryTitlesProvider);
    ref.invalidate(householdAlertsProvider);
    await Future.wait([
      ref.read(groceryPlanProvider(widget.groceryId).future),
      ref.read(groceryItemsProvider(widget.groceryId).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final planAsync = ref.watch(groceryPlanProvider(widget.groceryId));
    final itemsAsync = ref.watch(groceryItemsProvider(widget.groceryId));
    final backupNotifier = ref.read(backupRestoreProvider.notifier);
    final plan = planAsync.asData?.value;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan?['title']?.toString() ?? 'Grocery plan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Track what to buy and what is done',
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
        backgroundColor: neutral.background,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: neutral.textPrimary),
            color: neutral.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'edit' && plan != null) {
                showGroceryPlanEditor(context, ref, plan: plan);
              } else if (value == 'share') {
                backupNotifier.shareGroceries(context, widget.groceryId);
              } else if (value == 'history') {
                _showHistory(
                  context,
                  entityType: 'grocery_plan',
                  entityId: widget.groceryId,
                );
              }
            },
            itemBuilder: (_) => [
              _menuItem(FontAwesomeIcons.pen, 'edit', 'Edit plan', neutral),
              _menuItem(FontAwesomeIcons.shareNodes, 'share', 'Share plan', neutral),
              _menuItem(FontAwesomeIcons.clockRotateLeft, 'history', 'Plan history', neutral),
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  planAsync.when(
                    data: (data) => data == null
                        ? _ErrorCard(onRetry: _refresh)
                        : _PlanHeader(
                            plan: data,
                            onEdit: () => showGroceryPlanEditor(
                              context,
                              ref,
                              plan: data,
                            ),
                          ),
                    loading: () => const _HeaderLoading(),
                    error: (_, __) => _ErrorCard(onRetry: _refresh),
                  ),
                  const SizedBox(height: 18),
                  if (widget.desktopEmbedded) ...[
                    _DesktopItemActions(
                      onAddNew: () => showGroceryItemEditor(
                        context,
                        ref,
                        groceryId: widget.groceryId,
                      ),
                      onAddExisting: () => showExistingGroceryItemsSelector(
                        context,
                        ref,
                        groceryId: widget.groceryId,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _FilterBar(
                    selected: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                    items: itemsAsync.asData?.value ?? const [],
                  ),
                  const SizedBox(height: 14),
                  itemsAsync.when(
                    data: (items) {
                      final filtered = items.where((item) {
                        final done = item['status'] == 1;
                        if (_filter == 'pending') return !done;
                        if (_filter == 'done') return done;
                        if (_filter == 'overdue') {
                          final dueAt = GroceryCatalog.dateTimeFrom(item['due_at']);
                          return !done && dueAt != null && dueAt.isBefore(DateTime.now());
                        }
                        return true;
                      }).toList();

                      if (items.isEmpty) {
                        return _EmptyItems(
                          onAddNew: () => showGroceryItemEditor(
                            context,
                            ref,
                            groceryId: widget.groceryId,
                          ),
                          onAddExisting: () =>
                              showExistingGroceryItemsSelector(
                            context,
                            ref,
                            groceryId: widget.groceryId,
                          ),
                        );
                      }
                      if (filtered.isEmpty) {
                        return _NoFilterResults(filter: _filter);
                      }

                      return Column(
                        children: filtered
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _GroceryItemCard(
                                    item: item,
                                    onToggle: () => _toggleDone(item),
                                    onEdit: () => showGroceryItemEditor(
                                      context,
                                      ref,
                                      groceryId: widget.groceryId,
                                      item: item,
                                    ),
                                    onDelete: () => _deleteItem(item['id'] as int),
                                    onHistory: () => _showHistory(
                                      context,
                                      entityType: 'grocery_item',
                                      entityId: item['id'] as int,
                                    ),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const _ItemsLoading(),
                    error: (_, __) => _ErrorCard(onRetry: _refresh),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
      ),
      bottomNavigationBar: widget.desktopEmbedded ? null : Container(
        decoration: BoxDecoration(
          color: neutral.card,
          border: Border(top: BorderSide(color: neutral.divider)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: AddGroceryItemWidget(groceryId: widget.groceryId),
      ),
    );
  }

  Future<void> _toggleDone(Map<String, dynamic> item) async {
    final newStatus = item['status'] == 1 ? 0 : 1;
    await ref.read(dbServiceProvider).updateGroceryItemStatus(
          item['id'] as int,
          newStatus,
          DateTime.now().toIso8601String(),
        );
    refreshGroceryDashboard(ref, groceryId: widget.groceryId);
  }

  Future<void> _deleteItem(int id) async {
    final neutral = context.themeColors.neutral;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: neutral.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const CenteredFaIcon(FontAwesomeIcons.triangleExclamation, color: AppColors.danger),
            title: Text('Delete grocery item?', textAlign: TextAlign.center, style: TextStyle(color: neutral.textPrimary)),
            content: Text('The item, its alert, and its activity history will be removed.', textAlign: TextAlign.center, style: TextStyle(color: neutral.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await ref.read(dbServiceProvider).deleteGroceryItem(id);
    refreshGroceryDashboard(ref, groceryId: widget.groceryId);
  }

  Future<void> _showHistory(
    BuildContext context, {
    required String entityType,
    required int entityId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(
        future: ref.read(dbServiceProvider).getActivityLogs(
              entityType: entityType,
              entityId: entityId,
            ),
      ),
    );
  }
}



class _DesktopItemActions extends StatelessWidget {
  const _DesktopItemActions({required this.onAddNew, required this.onAddExisting});

  final VoidCallback onAddNew;
  final VoidCallback onAddExisting;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'List items',
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onAddExisting,
            icon: const Icon(Icons.playlist_add_rounded, size: 18),
            label: const Text('Add existing'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAddNew,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }
}
