import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../Grocery/Grocery/components/AddChoreWidget.dart';
import '../../Grocery/Grocery/components/AddGroceryItemWidget.dart';
import '../../Grocery/Grocery/components/AddGroceryTitleWidget.dart';
import '../../Grocery/Grocery/controller/grocery_controller.dart';
import '../../HomeScreen/controller/dashboard_provider.dart';
import '../../HomeScreen/controller/home_quote_provider.dart';
import '../../HomeScreen/widgets/dashboard_quick_actions.dart';
import '../../habitTracker/view/HabitsScreen.dart';
import '../../quotation/controller/quotation_controller.dart';
import '../../../utlis/app_router.dart';
import '../../../utlis/platform_capabilities.dart';
import 'desktop_navigation_scope.dart';

Future<void> showMainQuickCreateSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onInvoiceCreate,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => const _QuickCreateSheet(),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _QuickCreateAction.expense:
      await showQuickExpenseSheet(context, ref);
      break;
    case _QuickCreateAction.meter:
      await showQuickMeterReading(context, ref);
      break;
    case _QuickCreateAction.habit:
      await showCreateHabitSheet(context, ref);
      ref.invalidate(homeDashboardProvider);
      break;
    case _QuickCreateAction.groceryItem:
      await _showGroceryItemCreator(context, ref);
      ref.invalidate(homeDashboardProvider);
      break;
    case _QuickCreateAction.chore:
      await showChoreEditor(context, ref);
      ref.invalidate(homeDashboardProvider);
      break;
    case _QuickCreateAction.loan:
      await showQuickLoanForm(context, ref);
      break;
    case _QuickCreateAction.invoice:
      if (onInvoiceCreate != null) {
        onInvoiceCreate();
      } else {
        await openResponsiveModule(context, '${RoutesStr.invoices}/new');
      }
      ref.invalidate(homeDashboardProvider);
      break;
    case _QuickCreateAction.quotation:
      await context.push('${RoutesStr.quotes}?create=1');
      ref.invalidate(homeDashboardProvider);
      ref.invalidate(homeQuoteProvider);
      ref.invalidate(quotationCountProvider);
      break;
    case _QuickCreateAction.diary:
      await openQuickDiary(context, ref);
      break;
    case _QuickCreateAction.scan:
      await openQuickScanner(context, ref);
      break;
    case _QuickCreateAction.pill:
      await context.push(RoutesStr.pillReminderForm);
      ref.invalidate(homeDashboardProvider);
      break;
  }
}

Future<void> _showGroceryItemCreator(
  BuildContext context,
  WidgetRef ref,
) async {
  List<Map<String, dynamic>> plans;
  try {
    plans = await ref.read(groceryTitlesProvider.future);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not load grocery plans: $error')),
    );
    return;
  }

  if (plans.isEmpty) {
    await showGroceryPlanEditor(context, ref);
    ref.invalidate(groceryTitlesProvider);
    try {
      plans = await ref.read(groceryTitlesProvider.future);
    } catch (_) {
      plans = const <Map<String, dynamic>>[];
    }
  }

  if (plans.isEmpty || !context.mounted) return;

  int? groceryId;
  if (plans.length == 1) {
    groceryId = (plans.first['id'] as num?)?.toInt();
  } else {
    groceryId = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _GroceryPlanPicker(plans: plans),
    );
  }

  if (groceryId == null || !context.mounted) return;
  await showGroceryItemEditor(
    context,
    ref,
    groceryId: groceryId,
  );
}

class _QuickCreateSheet extends StatelessWidget {
  const _QuickCreateSheet();

  static const actions = <_QuickCreateItem>[
    _QuickCreateItem(
      id: _QuickCreateAction.expense,
      label: 'Expense',
      icon: Icons.add_card_rounded,
      color: Color(0xFFF43F5E),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.meter,
      label: 'Reading',
      icon: Icons.add_chart_rounded,
      color: Color(0xFF4F46E5),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.habit,
      label: 'Habit',
      icon: Icons.task_alt_rounded,
      color: Color(0xFF8B5CF6),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.groceryItem,
      label: 'Grocery item',
      icon: Icons.add_shopping_cart_rounded,
      color: Color(0xFF22C55E),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.chore,
      label: 'Chore',
      icon: Icons.cleaning_services_outlined,
      color: Color(0xFF16A34A),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.loan,
      label: 'Loan',
      icon: Icons.person_add_alt_1_rounded,
      color: Color(0xFF0891B2),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.invoice,
      label: 'Invoice',
      icon: Icons.post_add_rounded,
      color: Color(0xFF6366F1),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.quotation,
      label: 'Quotation',
      icon: Icons.request_quote_outlined,
      color: Color(0xFF7C3AED),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.diary,
      label: 'Diary entry',
      icon: Icons.edit_note_rounded,
      color: Color(0xFFEC4899),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.scan,
      label: 'Scan',
      icon: Icons.document_scanner_rounded,
      color: Color(0xFF0EA5E9),
    ),
    _QuickCreateItem(
      id: _QuickCreateAction.pill,
      label: 'Pill reminder',
      icon: Icons.medication_rounded,
      color: Color(0xFF14B8A6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick add',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              'Create a new record using the existing forms and services.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 600
                      ? 4
                      : constraints.maxWidth < 340
                          ? 2
                          : 3;
                  const spacing = AppSpacing.xs;
                  final width = (constraints.maxWidth -
                          ((columns - 1) * spacing)) /
                      columns;

                  final visibleActions = documentScannerCaptureSupported
                      ? actions
                      : actions
                          .where((action) => action.id != _QuickCreateAction.scan)
                          .toList(growable: false);

                  return SingleChildScrollView(
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: visibleActions
                          .map(
                            (action) => SizedBox(
                              width: width,
                              child: _QuickCreateCard(item: action),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCreateCard extends StatelessWidget {
  const _QuickCreateCard({required this.item});

  final _QuickCreateItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pop(context, item.id),
        child: SizedBox(
          height: 88,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(isDark ? .22 : .11),
                    borderRadius: AppRadius.small,
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(height: 7),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroceryPlanPicker extends StatelessWidget {
  const _GroceryPlanPicker({required this.plans});

  final List<Map<String, dynamic>> plans;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose grocery plan',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: plans.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final plan = plans[index];
                  final id = (plan['id'] as num?)?.toInt();
                  return ListTile(
                    leading: const Icon(Icons.shopping_basket_outlined),
                    title: Text(plan['title']?.toString() ?? 'Grocery plan'),
                    subtitle: Text(
                      plan['description']?.toString().trim().isNotEmpty == true
                          ? plan['description'].toString()
                          : 'Add an item to this plan',
                    ),
                    enabled: id != null,
                    onTap: id == null ? null : () => Navigator.pop(context, id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _QuickCreateAction {
  static const expense = 'expense';
  static const meter = 'meter';
  static const habit = 'habit';
  static const groceryItem = 'grocery_item';
  static const chore = 'chore';
  static const loan = 'loan';
  static const invoice = 'invoice';
  static const quotation = 'quotation';
  static const diary = 'diary';
  static const scan = 'scan';
  static const pill = 'pill';
}

class _QuickCreateItem {
  const _QuickCreateItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
}
