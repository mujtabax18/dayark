import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../../../controller/currency_notifier.dart';
import '../../../models/HomeLayoutSettings.dart';
import '../../../models/currency_setting.dart';
import '../../../models/dashboard_summary.dart';
import '../../../utlis/app_router.dart';
import '../controller/dashboard_provider.dart';

class DashboardSummaryGrid extends ConsumerWidget {
  const DashboardSummaryGrid({
    super.key,
    required this.summary,
    this.summaryOrder = HomeLayoutSettings.defaultSummaryOrder,
    this.visibleSummaryIds = HomeLayoutSettings.defaultVisibleSummaryIds,
  });

  final DashboardSummary summary;
  final List<int> summaryOrder;
  final Set<int> visibleSummaryIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exactExpenses = ref.watch(homeExpenseSummaryProvider).asData?.value;
    final currency = ref.watch(currencyProvider);
    final normalizedOrder =
        HomeLayoutSettings.normalizeSummaryOrder(summaryOrder)
            .where(visibleSummaryIds.contains)
            .toList(growable: false);
    final ids = summary.availableSummaryIds(normalizedOrder).toList();

    if (exactExpenses != null &&
        exactExpenses.transactionCount > 0 &&
        normalizedOrder.contains(3) &&
        !ids.contains(3)) {
      ids.add(3);
      ids.sort(
        (left, right) => normalizedOrder
            .indexOf(left)
            .compareTo(normalizedOrder.indexOf(right)),
      );
    }

    if (ids.isEmpty) {
      final hasVisibleSelection = visibleSummaryIds.any(
        HomeLayoutSettings.summaryFeatureIds.contains,
      );
      return AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppRadius.medium,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: AppRadius.small,
              ),
              child: Icon(
                Icons.space_dashboard_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasVisibleSelection
                        ? 'No summary data available'
                        : 'No summary cards selected',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasVisibleSelection
                        ? 'Summaries appear automatically when records are available.'
                        : 'Choose the summaries and their Home positions in settings.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 4
            : constraints.maxWidth >= 820
                ? 3
                : constraints.maxWidth < 350
                    ? 1
                    : 2;
        const spacing = AppSpacing.xs;
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: ids
              .map(
                (id) => SizedBox(
                  width: width,
                  height: 140,
                  child: _DetailedSummaryCard(
                    data: _dataFor(id, exactExpenses, currency),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  _DetailedSummaryData _dataFor(
    int id,
    HomeExpenseSummary? exactExpenses,
    CurrencySetting currency,
  ) {
    return switch (id) {
      1 => _meterData(),
      2 => _groceryData(),
      3 => _expenseData(exactExpenses, currency),
      5 => _diaryData(),
      6 => _habitData(),
      8 => _invoiceData(),
      9 => _loanData(currency),
      10 => _mediaData(),
      11 => _pillData(),
      12 => _scannerData(),
      _ => _DetailedSummaryData.empty(),
    };
  }

  _DetailedSummaryData _expenseData(
    HomeExpenseSummary? exactData,
    CurrencySetting currency,
  ) {
    final dashboardData = summary.expenses;
    final remaining = exactData?.remaining ?? dashboardData.remaining;
    final expense = exactData?.expense ?? dashboardData.expense;
    final income = exactData?.income ?? dashboardData.income;

    return _DetailedSummaryData(
      title: 'Expenses',
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFFF43F5E),
      route: RoutesStr.expense,
      primaryValue: currency.formatCompact(remaining),
      primaryLabel: 'active period balance',
      stats: [
        _SummaryStat('Spent', currency.formatCompact(expense)),
        _SummaryStat('Income', currency.formatCompact(income)),
      ],
    );
  }

  _DetailedSummaryData _meterData() {
    final data = summary.meters;
    final first = data.items.first;
    final unitLabels = data.items.map((item) => item.unitLabel).toSet();
    final unit = unitLabels.length == 1 ? unitLabels.first : 'units';

    return _DetailedSummaryData(
      title: 'Meter usage',
      icon: Icons.electric_meter_outlined,
      color: const Color(0xFF4F46E5),
      route: RoutesStr.meterList,
      primaryValue: '${_number(data.totalUnitsUsed)} $unit',
      primaryLabel: 'used from baseline',
      stats: [
        _SummaryStat('Meters', '${data.items.length}'),
        _SummaryStat('Latest', _nullableNumber(first.latestReading)),
      ],
    );
  }

  _DetailedSummaryData _diaryData() {
    return _DetailedSummaryData(
      title: 'Diary',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFFEC4899),
      route: RoutesStr.moodTracker,
      primaryValue: '${summary.diaryEntryCount}',
      primaryLabel: 'saved entries',
      stats: const [
        _SummaryStat('Type', 'Personal'),
        _SummaryStat('Storage', 'Offline'),
      ],
    );
  }

  _DetailedSummaryData _invoiceData() {
    return _DetailedSummaryData(
      title: 'Invoices',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFF6366F1),
      route: RoutesStr.invoices,
      primaryValue: '${summary.invoiceCount}',
      primaryLabel: 'saved invoices',
      stats: const [
        _SummaryStat('Status', 'Local'),
        _SummaryStat('Open', 'View all'),
      ],
    );
  }

  _DetailedSummaryData _mediaData() {
    return _DetailedSummaryData(
      title: 'Media Studio',
      icon: Icons.perm_media_rounded,
      color: const Color(0xFFE11D48),
      route: RoutesStr.multimedia,
      primaryValue: '${summary.mediaFileCount}',
      primaryLabel: 'media files',
      stats: const [
        _SummaryStat('Editor', 'Ready'),
        _SummaryStat('Files', 'Local'),
      ],
    );
  }

  _DetailedSummaryData _scannerData() {
    return _DetailedSummaryData(
      title: 'Doc Scanner',
      icon: Icons.document_scanner_rounded,
      color: const Color(0xFF0EA5E9),
      route: RoutesStr.scannerGallery,
      primaryValue: '${summary.scannedPageCount}',
      primaryLabel: 'scanned pages',
      stats: const [
        _SummaryStat('Gallery', 'Local'),
        _SummaryStat('Open', 'View all'),
      ],
    );
  }

  _DetailedSummaryData _habitData() {
    final data = summary.habits;

    return _DetailedSummaryData(
      title: 'Today’s habits',
      icon: Icons.track_changes_rounded,
      color: const Color(0xFF8B5CF6),
      route: RoutesStr.habits,
      primaryValue: '${(data.completionRate * 100).round()}%',
      primaryLabel: 'completed today',
      stats: [
        _SummaryStat('Done', '${data.completed}'),
        _SummaryStat('Due', '${data.due}'),
      ],
    );
  }

  _DetailedSummaryData _groceryData() {
    final data = summary.grocery;

    return _DetailedSummaryData(
      title: 'Grocery & chores',
      icon: Icons.shopping_basket_outlined,
      color: const Color(0xFF22C55E),
      route: RoutesStr.grocery,
      primaryValue: '${data.totalRemaining}',
      primaryLabel: 'tasks remaining',
      stats: [
        _SummaryStat('To buy', '${data.pendingItems}'),
        _SummaryStat('Chores', '${data.pendingChores}'),
      ],
    );
  }

  _DetailedSummaryData _pillData() {
    final data = summary.pills;

    return _DetailedSummaryData(
      title: 'Pill reminder',
      icon: Icons.medication_outlined,
      color: const Color(0xFF14B8A6),
      route: RoutesStr.pillReminder,
      primaryValue: '${data.pending}',
      primaryLabel: 'doses pending',
      stats: [
        _SummaryStat('Taken', '${data.taken}'),
        _SummaryStat('Missed', '${data.missed}'),
      ],
    );
  }

  _DetailedSummaryData _loanData(CurrencySetting currency) {
    final data = summary.loans;

    return _DetailedSummaryData(
      title: 'Digital Khata',
      icon: Icons.account_balance_wallet_outlined,
      color: const Color(0xFF0891B2),
      route: RoutesStr.loans,
      primaryValue: currency.formatCompact(data.toReceive),
      primaryLabel: 'total to receive',
      stats: [
        _SummaryStat('To pay', currency.formatCompact(data.toPay)),
        _SummaryStat('Overdue', currency.formatCompact(data.overdueAmount)),
      ],
    );
  }


  String _number(double value) => NumberFormat('#,##0.##').format(value);

  String _nullableNumber(double? value) =>
      value == null ? '—' : _number(value);
}

class _DetailedSummaryCard extends StatelessWidget {
  const _DetailedSummaryCard({required this.data});

  final _DetailedSummaryData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppSurface(
      onTap: () => openResponsiveModule(context, data.route),
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderRadius: AppRadius.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(isDark ? .22 : .11),
                  borderRadius: AppRadius.small,
                ),
                child: Icon(data.icon, size: 19, color: data.color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.primaryValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
          ),
          Text(
            data.primaryLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(child: _MiniStat(stat: data.stats[0])),
              const SizedBox(width: 6),
              Expanded(child: _MiniStat(stat: data.stats[1])),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.stat});

  final _SummaryStat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}

class _DetailedSummaryData {
  const _DetailedSummaryData({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    required this.primaryValue,
    required this.primaryLabel,
    required this.stats,
  });

  factory _DetailedSummaryData.empty() => const _DetailedSummaryData(
        title: '',
        icon: Icons.widgets_outlined,
        color: Colors.grey,
        route: RoutesStr.home,
        primaryValue: '',
        primaryLabel: '',
        stats: [_SummaryStat('', ''), _SummaryStat('', '')],
      );

  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final String primaryValue;
  final String primaryLabel;
  final List<_SummaryStat> stats;
}

class _SummaryStat {
  const _SummaryStat(this.label, this.value);

  final String label;
  final String value;
}
