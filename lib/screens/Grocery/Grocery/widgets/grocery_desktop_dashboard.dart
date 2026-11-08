part of '../view/grocery_title.dart';

class _DesktopGroceryDashboard extends StatelessWidget {
  const _DesktopGroceryDashboard({
    required this.dashboard,
    required this.plans,
    required this.alerts,
    required this.selectedPlanId,
    required this.onSelectPlan,
    required this.onClearSelection,
    required this.onRefresh,
    required this.onShowAlerts,
    required this.onShowHistory,
    required this.onCreatePlan,
    required this.onEditPlan,
    required this.onDeletePlan,
    required this.onSharePlan,
    required this.onShareAll,
    required this.onRestore,
    this.onDesktopBack,
  });

  final AsyncValue<Map<String, dynamic>> dashboard;
  final AsyncValue<List<Map<String, dynamic>>> plans;
  final AsyncValue<List<Map<String, dynamic>>> alerts;
  final int? selectedPlanId;
  final ValueChanged<int> onSelectPlan;
  final VoidCallback onClearSelection;
  final Future<void> Function() onRefresh;
  final VoidCallback onShowAlerts;
  final VoidCallback onShowHistory;
  final VoidCallback onCreatePlan;
  final ValueChanged<Map<String, dynamic>> onEditPlan;
  final ValueChanged<int> onDeletePlan;
  final ValueChanged<int> onSharePlan;
  final VoidCallback onShareAll;
  final VoidCallback onRestore;
  final VoidCallback? onDesktopBack;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final unread = alerts.asData?.value.where((e) => e['is_read'] == 0).length ?? 0;
    final availablePlans = plans.asData?.value ?? const <Map<String, dynamic>>[];
    final effectiveSelectedPlanId = selectedPlanId != null &&
            availablePlans.any((plan) => plan['id'] == selectedPlanId)
        ? selectedPlanId
        : null;

    return Scaffold(
      backgroundColor: neutral.background,
      body: Column(
        children: [
          _DesktopGroceryHeader(
            unread: unread,
            onBack: onDesktopBack,
            onAlerts: onShowAlerts,
            onHistory: onShowHistory,
            onShareAll: onShareAll,
            onRestore: onRestore,
            onCreatePlan: onCreatePlan,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 330,
                    child: _DesktopGroceryListRail(
                      plans: plans,
                      selectedPlanId: effectiveSelectedPlanId,
                      onSelectPlan: onSelectPlan,
                      onCreatePlan: onCreatePlan,
                      onRefresh: onRefresh,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: neutral.card,
                          border: Border.all(color: neutral.divider),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: effectiveSelectedPlanId == null
                            ? _DesktopGroceryOverview(
                                dashboard: dashboard,
                                plans: plans,
                                alerts: alerts,
                                onCreatePlan: onCreatePlan,
                                onSelectPlan: onSelectPlan,
                                onEditPlan: onEditPlan,
                                onDeletePlan: onDeletePlan,
                                onSharePlan: onSharePlan,
                                onShowAlerts: onShowAlerts,
                              )
                            : Column(
                                children: [
                                  _SelectedListTopBar(
                                    onOverview: onClearSelection,
                                    onCreatePlan: onCreatePlan,
                                  ),
                                  Expanded(
                                    child: GroceryListPage(
                                      key: ValueKey(effectiveSelectedPlanId),
                                      groceryId: effectiveSelectedPlanId!,
                                      desktopEmbedded: true,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopGroceryHeader extends StatelessWidget {
  const _DesktopGroceryHeader({
    required this.unread,
    required this.onBack,
    required this.onAlerts,
    required this.onHistory,
    required this.onShareAll,
    required this.onRestore,
    required this.onCreatePlan,
  });

  final int unread;
  final VoidCallback? onBack;
  final VoidCallback onAlerts;
  final VoidCallback onHistory;
  final VoidCallback onShareAll;
  final VoidCallback onRestore;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton.filledTonal(
              tooltip: 'Back to dashboard',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grocery dashboard', style: TextStyle(color: neutral.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('Manage all grocery lists from one workspace', style: TextStyle(color: neutral.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: IconButton.filledTonal(
              tooltip: 'Alerts',
              onPressed: onAlerts,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              if (value == 'history') onHistory();
              if (value == 'share') onShareAll();
              if (value == 'restore') onRestore();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'history', child: Text('Activity history')),
              PopupMenuItem(value: 'share', child: Text('Share grocery data')),
              PopupMenuItem(value: 'restore', child: Text('Restore backup')),
            ],
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onCreatePlan,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New list'),
          ),
        ],
      ),
    );
  }
}

class _DesktopGroceryListRail extends StatelessWidget {
  const _DesktopGroceryListRail({
    required this.plans,
    required this.selectedPlanId,
    required this.onSelectPlan,
    required this.onCreatePlan,
    required this.onRefresh,
  });

  final AsyncValue<List<Map<String, dynamic>>> plans;
  final int? selectedPlanId;
  final ValueChanged<int> onSelectPlan;
  final VoidCallback onCreatePlan;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
            child: Row(
              children: [
                Expanded(child: Text('Grocery lists', style: TextStyle(color: neutral.textPrimary, fontSize: 16, fontWeight: FontWeight.w800))),
                IconButton(onPressed: onCreatePlan, tooltip: 'New list', icon: const Icon(Icons.add_rounded)),
              ],
            ),
          ),
          Divider(height: 1, color: neutral.divider),
          Expanded(
            child: plans.when(
              data: (data) => data.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_basket_outlined, size: 40, color: neutral.textSecondary),
                            const SizedBox(height: 12),
                            Text('No grocery lists yet', style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            FilledButton(onPressed: onCreatePlan, child: const Text('Create list')),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(10),
                        itemCount: data.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final plan = data[index];
                          final id = plan['id'] as int;
                          final selected = id == selectedPlanId;
                          final pending = plan['pending_count'] ?? plan['pending_items'] ?? 0;
                          return Material(
                            color: selected ? Theme.of(context).colorScheme.primaryContainer : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              selected: selected,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              leading: CircleAvatar(
                                backgroundColor: selected ? Theme.of(context).colorScheme.primary.withOpacity(.14) : neutral.background,
                                child: Icon(Icons.shopping_cart_outlined, size: 19, color: selected ? Theme.of(context).colorScheme.primary : neutral.textSecondary),
                              ),
                              title: Text(plan['title']?.toString() ?? 'Grocery list', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w700)),
                              subtitle: Text('$pending items to buy', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: neutral.textSecondary, fontSize: 11)),
                              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                              onTap: () => onSelectPlan(id),
                            ),
                          );
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Padding(padding: const EdgeInsets.all(20), child: Text('Could not load lists.\n$error', textAlign: TextAlign.center))),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedListTopBar extends StatelessWidget {
  const _SelectedListTopBar({required this.onOverview, required this.onCreatePlan});
  final VoidCallback onOverview;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: neutral.divider))),
      child: Row(
        children: [
          TextButton.icon(onPressed: onOverview, icon: const Icon(Icons.dashboard_outlined, size: 18), label: const Text('Overview')),
          const Spacer(),
          OutlinedButton.icon(onPressed: onCreatePlan, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New list')),
        ],
      ),
    );
  }
}

class _DesktopGroceryOverview extends StatelessWidget {
  const _DesktopGroceryOverview({
    required this.dashboard,
    required this.plans,
    required this.alerts,
    required this.onCreatePlan,
    required this.onSelectPlan,
    required this.onEditPlan,
    required this.onDeletePlan,
    required this.onSharePlan,
    required this.onShowAlerts,
  });

  final AsyncValue<Map<String, dynamic>> dashboard;
  final AsyncValue<List<Map<String, dynamic>>> plans;
  final AsyncValue<List<Map<String, dynamic>>> alerts;
  final VoidCallback onCreatePlan;
  final ValueChanged<int> onSelectPlan;
  final ValueChanged<Map<String, dynamic>> onEditPlan;
  final ValueChanged<int> onDeletePlan;
  final ValueChanged<int> onSharePlan;
  final VoidCallback onShowAlerts;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final data = dashboard.asData?.value ?? const <String, dynamic>{};
    final listData = plans.asData?.value ?? const <Map<String, dynamic>>[];
    final alertData = alerts.asData?.value ?? const <Map<String, dynamic>>[];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _DesktopMetric(label: 'Active lists', value: '${data['plans'] ?? 0}', icon: Icons.list_alt_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _DesktopMetric(label: 'Items to buy', value: '${data['pending_items'] ?? 0}', icon: Icons.shopping_cart_checkout_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _DesktopMetric(label: 'Open chores', value: '${data['pending_chores'] ?? 0}', icon: Icons.cleaning_services_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _DesktopMetric(label: 'Overdue', value: '${data['overdue'] ?? 0}', icon: Icons.warning_amber_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text('Recent grocery lists', style: TextStyle(color: neutral.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
              TextButton.icon(onPressed: onCreatePlan, icon: const Icon(Icons.add_rounded), label: const Text('New list')),
            ],
          ),
          const SizedBox(height: 10),
          if (listData.isEmpty)
            _EmptyCard(icon: FontAwesomeIcons.basketShopping, title: 'No grocery plan yet', message: 'Create your first grocery list to start planning.', actionLabel: 'Create list', onAction: onCreatePlan)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.25),
              itemCount: listData.length > 6 ? 6 : listData.length,
              itemBuilder: (context, index) {
                final plan = listData[index];
                return _GroceryPlanCard(
                  plan: plan,
                  onOpen: () => onSelectPlan(plan['id'] as int),
                  onEdit: () => onEditPlan(plan),
                  onDelete: () => onDeletePlan(plan['id'] as int),
                  onShare: () => onSharePlan(plan['id'] as int),
                );
              },
            ),
          if (alertData.isNotEmpty) ...[
            const SizedBox(height: 24),
            _AlertPreview(alert: alertData.first, remaining: alertData.length - 1, onTap: onShowAlerts),
          ],
        ],
      ),
    );
  }
}

class _DesktopMetric extends StatelessWidget {
  const _DesktopMetric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: neutral.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: neutral.divider)),
      child: Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: primary.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: primary, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: neutral.textPrimary, fontSize: 21, fontWeight: FontWeight.w900)), const SizedBox(height: 2), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: neutral.textSecondary, fontSize: 11))])),
        ],
      ),
    );
  }
}
