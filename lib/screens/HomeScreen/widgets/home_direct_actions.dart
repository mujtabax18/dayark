import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_tokens.dart';
import '../../../models/HomeLayoutSettings.dart';
import '../../../models/dashboard_summary.dart';
import '../../../screens/habitTracker/view/HabitsScreen.dart';
import '../../../screens/quotation/controller/quotation_controller.dart';
import '../../../utlis/app_router.dart';
import '../../../utlis/platform_capabilities.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../navigation/widgets/quick_create_sheet.dart';
import '../controller/dashboard_provider.dart';
import '../controller/home_quote_provider.dart';
import 'dashboard_quick_actions.dart';

class HomeDirectActions extends ConsumerWidget {
  const HomeDirectActions({
    super.key,
    this.summary,
    this.actionOrder = HomeLayoutSettings.defaultQuickActionOrder,
    this.visibleActionIds = HomeLayoutSettings.defaultVisibleQuickActionIds,
  });

  final DashboardSummary? summary;
  final List<String> actionOrder;
  final Set<String> visibleActionIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionsById = _buildActions(context, ref);
    final normalizedOrder = HomeLayoutSettings.normalizeQuickActionOrder(
      actionOrder,
    );
    final actions = normalizedOrder
        .where(visibleActionIds.contains)
        .map((id) => actionsById[id])
        .whereType<_HomeAction>()
        .toList(growable: false);

    if (actions.isEmpty) {
      return _EmptyActions(
        onCustomize: () => context.push(RoutesStr.homeSetting),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 6
            : constraints.maxWidth >= 520
                ? 5
                : constraints.maxWidth < 340
                    ? 3
                    : 4;
        const spacing = AppSpacing.xs;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions
              .map(
                (action) => SizedBox.square(
                  dimension: itemWidth,
                  child: _ActionButton(action: action),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Map<String, _HomeAction> _buildActions(
    BuildContext context,
    WidgetRef ref,
  ) {
    final data = summary;
    return <String, _HomeAction>{
      HomeQuickActionId.expense: _HomeAction(
        label: 'Expense',
        icon: Icons.add_card_rounded,
        color: const Color(0xFFF43F5E),
        onPressed: () => showQuickExpenseSheet(context, ref),
      ),
      HomeQuickActionId.meterReading: _HomeAction(
        label: 'Reading',
        icon: Icons.add_chart_rounded,
        color: const Color(0xFF4F46E5),
        onPressed: () => showQuickMeterReading(context, ref),
      ),
      HomeQuickActionId.habit: _HomeAction(
        label: data?.hasHabitSummary == true ? 'Habit' : 'Add habit',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF8B5CF6),
        onPressed: () async {
          if (data?.hasHabitSummary == true) {
            await showQuickHabitUpdate(context, ref, data!.habits);
          } else {
            await showCreateHabitSheet(context, ref);
            ref.invalidate(homeDashboardProvider);
          }
        },
      ),
      HomeQuickActionId.grocery: _HomeAction(
        label: 'Grocery',
        icon: Icons.shopping_cart_checkout_rounded,
        color: const Color(0xFF22C55E),
        onPressed: () async {
          if (data?.hasGrocerySummary == true) {
            await showQuickGroceryUpdate(context, ref, data!.grocery);
          } else {
            await context.push(RoutesStr.grocery);
            ref.invalidate(homeDashboardProvider);
          }
        },
      ),
      HomeQuickActionId.pill: _HomeAction(
        label: data?.hasPillSummary == true ? 'Take pill' : 'Add pill',
        icon: Icons.medication_rounded,
        color: const Color(0xFF14B8A6),
        onPressed: () async {
          if (data?.hasPillSummary == true) {
            await showQuickPillUpdate(context, ref, data!.pills);
          } else {
            await context.push(RoutesStr.pillReminderForm);
            ref.invalidate(homeDashboardProvider);
          }
        },
      ),
      HomeQuickActionId.loan: _HomeAction(
        label: 'Loan',
        icon: Icons.person_add_alt_1_rounded,
        color: const Color(0xFF0891B2),
        onPressed: () => showQuickLoanForm(context, ref),
      ),
      HomeQuickActionId.invoice: _HomeAction(
        label: 'Invoice',
        icon: Icons.post_add_rounded,
        color: const Color(0xFF6366F1),
        onPressed: () async {
          await openResponsiveModule(context, '${RoutesStr.invoices}/new');
          ref.invalidate(homeDashboardProvider);
        },
      ),
      HomeQuickActionId.quotation: _HomeAction(
        label: 'Quote',
        icon: Icons.format_quote_rounded,
        color: const Color(0xFF7C3AED),
        onPressed: () async {
          await context.push('${RoutesStr.quotes}?create=1');
          ref.invalidate(homeDashboardProvider);
          ref.invalidate(homeQuoteProvider);
          ref.invalidate(quotationCountProvider);
        },
      ),
      HomeQuickActionId.media: _HomeAction(
        label: 'Media',
        icon: Icons.auto_fix_high_rounded,
        color: const Color(0xFFE11D48),
        onPressed: () => showMediaQuickActions(context, ref),
      ),
      HomeQuickActionId.diary: _HomeAction(
        label: 'Diary',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFFEC4899),
        onPressed: () => openQuickDiary(context, ref),
      ),
      HomeQuickActionId.scan: _HomeAction(
        label: documentScannerCaptureSupported ? 'Scan' : 'Documents',
        icon: Icons.document_scanner_rounded,
        color: const Color(0xFF0EA5E9),
        onPressed: () => openQuickScanner(context, ref),
      ),
    };
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final _HomeAction action;

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
        onTap: action.onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: action.color.withOpacity(isDark ? .22 : .11),
                  borderRadius: AppRadius.small,
                ),
                child: Icon(action.icon, size: 19, color: action.color),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
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
    );
  }
}

class _EmptyActions extends StatelessWidget {
  const _EmptyActions({required this.onCustomize});

  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onCustomize,
      icon: const Icon(Icons.tune_rounded),
      label: const Text('Choose quick actions'),
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
}

class HomeCreateDock extends ConsumerWidget {
  const HomeCreateDock({
    super.key,
    required this.onSettingsPressed,
    this.actionOrder = HomeLayoutSettings.defaultQuickActionOrder,
    this.visibleActionIds = HomeLayoutSettings.defaultVisibleQuickActionIds,
  });

  final VoidCallback onSettingsPressed;
  final List<String> actionOrder;
  final Set<String> visibleActionIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final actionLimit = screenWidth < 380 ? 1 : (screenWidth < 460 ? 2 : 3);
    final titleWidth = screenWidth < 380 ? 82.0 : 104.0;
    final ordered = HomeLayoutSettings.normalizeQuickActionOrder(actionOrder)
        .where(visibleActionIds.contains)
        .take(actionLimit)
        .toList(growable: false);
    final actions = ordered
        .map((id) => _dockActionFor(id, context, ref))
        .whereType<_DockAction>()
        .toList(growable: false);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(.14),
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.large,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
            child: Row(
              children: [
                SizedBox(
                  width: titleWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create new',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quickly add anything.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontSize: 9.5,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final action in actions) ...[
                        Flexible(child: _DockActionButton(action: action)),
                        const SizedBox(width: 2),
                      ],
                      _DockMoreButton(
                        onPressed: () => showMainQuickCreateSheet(context, ref),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: onSettingsPressed,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                ),
                FloatingActionButton.small(
                  heroTag: 'home_create_dock_add',
                  tooltip: 'Quick add',
                  elevation: 0,
                  highlightElevation: 1,
                  onPressed: () => showMainQuickCreateSheet(context, ref),
                  child: const Icon(Icons.add_rounded, size: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _DockAction? _dockActionFor(
    String id,
    BuildContext context,
    WidgetRef ref,
  ) {
    return switch (id) {
      HomeQuickActionId.expense => _DockAction(
          label: 'Expense',
          icon: Icons.add_card_rounded,
          color: const Color(0xFFF43F5E),
          onPressed: () => showQuickExpenseSheet(context, ref),
        ),
      HomeQuickActionId.meterReading => _DockAction(
          label: 'Reading',
          icon: Icons.add_chart_rounded,
          color: const Color(0xFF4F46E5),
          onPressed: () => showQuickMeterReading(context, ref),
        ),
      HomeQuickActionId.habit => _DockAction(
          label: 'Habit',
          icon: Icons.star_rounded,
          color: const Color(0xFF8B5CF6),
          onPressed: () async {
            await showCreateHabitSheet(context, ref);
            ref.invalidate(homeDashboardProvider);
          },
        ),
      HomeQuickActionId.grocery => _DockAction(
          label: 'Grocery',
          icon: Icons.shopping_cart_rounded,
          color: const Color(0xFF22C55E),
          onPressed: () async {
            await context.push(RoutesStr.grocery);
            ref.invalidate(homeDashboardProvider);
          },
        ),
      HomeQuickActionId.pill => _DockAction(
          label: 'Pill',
          icon: Icons.medication_rounded,
          color: const Color(0xFF14B8A6),
          onPressed: () async {
            await context.push(RoutesStr.pillReminderForm);
            ref.invalidate(homeDashboardProvider);
          },
        ),
      HomeQuickActionId.loan => _DockAction(
          label: 'Loan',
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF0891B2),
          onPressed: () => showQuickLoanForm(context, ref),
        ),
      HomeQuickActionId.invoice => _DockAction(
          label: 'Invoice',
          icon: Icons.post_add_rounded,
          color: const Color(0xFF6366F1),
          onPressed: () async {
            await openResponsiveModule(context, '${RoutesStr.invoices}/new');
            ref.invalidate(homeDashboardProvider);
          },
        ),
      HomeQuickActionId.quotation => _DockAction(
          label: 'Quote',
          icon: Icons.format_quote_rounded,
          color: const Color(0xFF7C3AED),
          onPressed: () async {
            await context.push('${RoutesStr.quotes}?create=1');
            ref.invalidate(homeDashboardProvider);
            ref.invalidate(homeQuoteProvider);
            ref.invalidate(quotationCountProvider);
          },
        ),
      HomeQuickActionId.media => _DockAction(
          label: 'Media',
          icon: Icons.auto_fix_high_rounded,
          color: const Color(0xFFE11D48),
          onPressed: () => showMediaQuickActions(context, ref),
        ),
      HomeQuickActionId.diary => _DockAction(
          label: 'Diary',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFFEC4899),
          onPressed: () => openQuickDiary(context, ref),
        ),
      HomeQuickActionId.scan => _DockAction(
          label: documentScannerCaptureSupported ? 'Scan' : 'Documents',
          icon: Icons.document_scanner_rounded,
          color: const Color(0xFF0EA5E9),
          onPressed: () => openQuickScanner(context, ref),
        ),
      _ => null,
    };
  }
}

class _DockActionButton extends StatelessWidget {
  const _DockActionButton({required this.action});

  final _DockAction action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: action.onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 17, color: action.color),
            const SizedBox(height: 3),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockMoreButton extends StatelessWidget {
  const _DockMoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz_rounded, size: 18, color: scheme.primary),
            const SizedBox(height: 3),
            Text(
              'More',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockAction {
  const _DockAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
}
