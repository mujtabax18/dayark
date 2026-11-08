import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_x.dart';
import '../../../../core/design/responsive_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../utlis/app_router.dart';
import '../../../Settings/controller/backup_restore_Provider.dart';
import '../components/AddChoreWidget.dart';
import '../components/AddGroceryTitleWidget.dart';
import '../controller/grocery_controller.dart';
import '../shared/grocery_catalog.dart';
import 'grocery_item.dart';
import '../../../../core/widgets/common/app_empty_state.dart';
import '../../../../core/widgets/common/centered_fa_icon.dart';
part '../widgets/grocery_title_dashboard_widgets.dart';
part '../widgets/grocery_desktop_dashboard.dart';
part '../widgets/grocery_title_sheet_widgets.dart';

class GroceryTitlesPage extends ConsumerStatefulWidget {
  const GroceryTitlesPage({super.key, this.onDesktopBack});

  final VoidCallback? onDesktopBack;

  @override
  ConsumerState<GroceryTitlesPage> createState() => _GroceryTitlesPageState();
}

class _GroceryTitlesPageState extends ConsumerState<GroceryTitlesPage> {
  int? _desktopSelectedPlanId;
  Future<void> _refresh() async {
    ref.invalidate(groceryDashboardProvider);
    ref.invalidate(groceryTitlesProvider);
    ref.invalidate(householdChoresProvider);
    ref.invalidate(householdAlertsProvider);
    await Future.wait([
      ref.read(groceryDashboardProvider.future),
      ref.read(groceryTitlesProvider.future),
      ref.read(householdChoresProvider.future),
      ref.read(householdAlertsProvider.future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final dashboard = ref.watch(groceryDashboardProvider);
    final plans = ref.watch(groceryTitlesProvider);
    final chores = ref.watch(householdChoresProvider);
    final alerts = ref.watch(householdAlertsProvider);
    final backupNotifier = ref.read(backupRestoreProvider.notifier);

    if (context.isDesktop) {
      return _DesktopGroceryDashboard(
        dashboard: dashboard,
        plans: plans,
        alerts: alerts,
        selectedPlanId: _desktopSelectedPlanId,
        onSelectPlan: (id) => setState(() => _desktopSelectedPlanId = id),
        onClearSelection: () => setState(() => _desktopSelectedPlanId = null),
        onRefresh: _refresh,
        onDesktopBack: widget.onDesktopBack,
        onShowAlerts: () => _showAlerts(context),
        onShowHistory: () => _showActivityHistory(context),
        onCreatePlan: () => showGroceryPlanEditor(context, ref),
        onEditPlan: (plan) => showGroceryPlanEditor(context, ref, plan: plan),
        onDeletePlan: (id) => _confirmDeletePlan(context, id),
        onSharePlan: (id) => backupNotifier.shareGroceries(context, id),
        onShareAll: () => backupNotifier.shareAllGroceries(context),
        onRestore: () => backupNotifier.restoreGroceries(context),
      );
    }

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Home management',
              style: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Groceries, chores and alerts',
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: neutral.background,
        elevation: 0,
        actions: [
          alerts.when(
            data: (data) {
              final unread = data.where((item) => item['is_read'] == 0).length;
              return _AlertButton(
                unreadCount: unread,
                onTap: () => _showAlerts(context),
              );
            },
            loading: () => _AlertButton(onTap: () => _showAlerts(context)),
            error: (_, __) => _AlertButton(onTap: () => _showAlerts(context)),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: neutral.textPrimary),
            color: neutral.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'share') {
                backupNotifier.shareAllGroceries(context);
              } else if (value == 'restore') {
                backupNotifier.restoreGroceries(context);
              } else if (value == 'history') {
                _showActivityHistory(context);
              }
            },
            itemBuilder: (_) => [
              _menuItem(FontAwesomeIcons.shareNodes, 'share', 'Share grocery data', neutral),
              _menuItem(FontAwesomeIcons.clockRotateLeft, 'history', 'Activity history', neutral),
              _menuItem(FontAwesomeIcons.rotate, 'restore', 'Restore backup', neutral),
            ],
          ),
        ],
      ),
      body: ResponsivePageFrame(
        maxWidth: 1280,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _DashboardHero(
                    dashboard: dashboard,
                    onCreatePlan: () => showGroceryPlanEditor(context, ref),
                    onCreateChore: () => showChoreEditor(context, ref),
                  ),
                  const SizedBox(height: 16),
                  _StatsGrid(dashboard: dashboard),
                  const SizedBox(height: 18),
                  alerts.when(
                    data: (data) => data.isEmpty
                        ? const SizedBox.shrink()
                        : _AlertPreview(
                            alert: data.first,
                            remaining: data.length - 1,
                            onTap: () => _showAlerts(context),
                          ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    title: 'Grocery plans',
                    subtitle: 'Keep separate monthly, weekly or special lists.',
                    actionLabel: 'New plan',
                    onAction: () => showGroceryPlanEditor(context, ref),
                  ),
                  const SizedBox(height: 12),
                  plans.when(
                    data: (data) => data.isEmpty
                        ? _EmptyCard(
                            icon: FontAwesomeIcons.basketShopping,
                            title: 'No grocery plan yet',
                            message: 'Create a monthly plan and add everything you need to buy.',
                            actionLabel: 'Create first plan',
                            onAction: () => showGroceryPlanEditor(context, ref),
                          )
                        : Column(
                            children: data
                                .map((plan) => Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _GroceryPlanCard(
                                        plan: plan,
                                        onOpen: () => context.push(
                                          '${RoutesStr.groceryItem}/${plan['id']}',
                                        ),
                                        onEdit: () => showGroceryPlanEditor(
                                          context,
                                          ref,
                                          plan: plan,
                                        ),
                                        onDelete: () => _confirmDeletePlan(
                                          context,
                                          plan['id'] as int,
                                        ),
                                        onShare: () => backupNotifier.shareGroceries(
                                          context,
                                          plan['id'] as int,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                    loading: () => const _LoadingCards(),
                    error: (error, _) => _ErrorCard(
                      message: 'Could not load grocery plans.\n$error',
                      onRetry: _refresh,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Household chores',
                    subtitle: 'Timed tasks with repeat rules and delay tracking.',
                    actionLabel: 'Add chore',
                    onAction: () => showChoreEditor(context, ref),
                  ),
                  const SizedBox(height: 12),
                  chores.when(
                    data: (data) {
                      final visible = data.take(8).toList();
                      if (visible.isEmpty) {
                        return _EmptyCard(
                          icon: FontAwesomeIcons.broom,
                          title: 'No household chores',
                          message: 'Add a timed task and the app will track if it is late.',
                          actionLabel: 'Add first chore',
                          onAction: () => showChoreEditor(context, ref),
                        );
                      }
                      return Column(
                        children: visible
                            .map((chore) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _ChoreCard(
                                    chore: chore,
                                    onToggle: () => _toggleChore(chore),
                                    onEdit: () => showChoreEditor(
                                      context,
                                      ref,
                                      chore: chore,
                                    ),
                                    onDelete: () => _confirmDeleteChore(
                                      context,
                                      chore['id'] as int,
                                    ),
                                    onHistory: () => _showActivityHistory(
                                      context,
                                      entityType: 'chore',
                                      entityId: chore['id'] as int,
                                    ),
                                  ),
                                ))
                            .toList(),
                      );
                    },
                    loading: () => const _LoadingCards(count: 3),
                    error: (error, _) => _ErrorCard(
                      message: 'Could not load household chores.\n$error',
                      onRetry: _refresh,
                    ),
                  ),
                ]),
              ),
            ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showChoreEditor(context, ref),
                    icon: const CenteredFaIcon(FontAwesomeIcons.broom, size: 16),
                    label: const Text('Add chore'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showGroceryPlanEditor(context, ref),
                    icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 16),
                    label: const Text('New plan'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleChore(Map<String, dynamic> chore) async {
    final current = chore['status']?.toString() ?? 'pending';
    await ref.read(dbServiceProvider).updateHouseholdChoreStatus(
          chore['id'] as int,
          current == 'completed' ? 'pending' : 'completed',
        );
    refreshGroceryDashboard(ref);
  }

  Future<void> _confirmDeletePlan(BuildContext context, int id) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Delete grocery plan?',
      message: 'The plan, all of its items, alerts, and activity history will be removed.',
    );
    if (!confirmed) return;
    await ref.read(dbServiceProvider).deleteGroceryTitle(id);
    if (_desktopSelectedPlanId == id && mounted) {
      setState(() => _desktopSelectedPlanId = null);
    }
    refreshGroceryDashboard(ref);
  }

  Future<void> _confirmDeleteChore(BuildContext context, int id) async {
    final confirmed = await _confirmDelete(
      context,
      title: 'Delete household chore?',
      message: 'This chore and its activity history will be removed.',
    );
    if (!confirmed) return;
    await ref.read(dbServiceProvider).deleteHouseholdChore(id);
    refreshGroceryDashboard(ref);
  }

  Future<void> _showAlerts(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlertsSheet(ref: ref),
    ).then((_) => refreshGroceryDashboard(ref));
  }

  Future<void> _showActivityHistory(
    BuildContext context, {
    String? entityType,
    int? entityId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ActivitySheet(
        service: ref.read(dbServiceProvider),
        entityType: entityType,
        entityId: entityId,
      ),
    );
  }
}

