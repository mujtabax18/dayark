import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../controller/currency_notifier.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/widgets/common/app_surface.dart';
import '../../../models/HomeLayoutSettings.dart';
import '../../../models/currency_setting.dart';
import '../../../models/dashboard_summary.dart';
import '../../../utlis/app_router.dart';
import '../controller/dashboard_provider.dart';

class GlanceDashboardSummaries extends ConsumerWidget {
  const GlanceDashboardSummaries({
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
    final ids = HomeLayoutSettings.normalizeSummaryOrder(summaryOrder)
        .where(visibleSummaryIds.contains)
        .toList(growable: false);

    if (ids.isEmpty) {
      return AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.view_week_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                'No summaries selected. Choose the items you want to see in Home settings.',
              ),
            ),
          ],
        ),
      );
    }

    final items = ids
        .map(
          (id) =>
              _dataFor(id, exactExpenses: exactExpenses, currency: currency),
        )
        .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          final columns = constraints.maxWidth >= 1120 ? 6 : 4;
          final width = (constraints.maxWidth - 16) / columns;
          return AppSurface(
            padding: const EdgeInsets.all(8),
            borderRadius: AppRadius.large,
            child: Wrap(
              spacing: 0,
              runSpacing: AppSpacing.xs,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: width,
                      height: 72,
                      child: _GlanceSummaryItem(data: item),
                    ),
                  )
                  .toList(growable: false),
            ),
          );
        }

        return AppSurface(
          padding: EdgeInsets.zero,
          borderRadius: AppRadius.large,
          child: SizedBox(
            height: 90,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              itemBuilder: (context, index) => SizedBox(
                width: 112,
                child: _GlanceSummaryItem(data: items[index]),
              ),
            ),
          ),
        );
      },
    );
  }

  _GlanceSummaryData _dataFor(
    int id, {
    required HomeExpenseSummary? exactExpenses,
    required CurrencySetting currency,
  }) {
    return switch (id) {
      1 => _GlanceSummaryData(
        title: 'Meters',
        value: _number(summary.meters.totalUnitsUsed),
        detail: '${summary.meters.items.length} active',
        icon: Icons.electric_meter_rounded,
        color: const Color(0xFF4F46E5),
        route: RoutesStr.meterList,
      ),
      2 => _GlanceSummaryData(
        title: 'Grocery',
        value: '${summary.grocery.totalRemaining}',
        detail: 'Remaining',
        icon: Icons.shopping_cart_rounded,
        color: const Color(0xFF22C55E),
        route: RoutesStr.grocery,
      ),
      3 => _GlanceSummaryData(
        title: 'Expenses',
        value: currency.formatCompact(
          exactExpenses?.expense ?? summary.expenses.expense,
        ),
        detail: 'Spent',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFF43F5E),
        route: RoutesStr.expense,
      ),
      5 => _GlanceSummaryData(
        title: 'Diary',
        value: '${summary.diaryEntryCount}',
        detail: 'Entries',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFFEC4899),
        route: RoutesStr.moodTracker,
      ),
      6 => _GlanceSummaryData(
        title: 'Habits',
        value: '${summary.habits.completed}/${summary.habits.total}',
        detail: 'Completed',
        icon: Icons.stars_rounded,
        color: const Color(0xFF8B5CF6),
        route: RoutesStr.habits,
      ),
      8 => _GlanceSummaryData(
        title: 'Invoices',
        value: '${summary.invoiceCount}',
        detail: 'Saved',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF6366F1),
        route: RoutesStr.invoices,
      ),
      9 => _GlanceSummaryData(
        title: 'Loans',
        value: currency.formatCompact(summary.loans.toReceive),
        detail: 'To receive',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF0891B2),
        route: RoutesStr.loans,
      ),
      10 => _GlanceSummaryData(
        title: 'Media',
        value: '${summary.mediaFileCount}',
        detail: 'Files',
        icon: Icons.perm_media_rounded,
        color: const Color(0xFFE11D48),
        route: RoutesStr.multimedia,
      ),
      11 => _GlanceSummaryData(
        title: 'Pills',
        value: '${summary.pills.pending}',
        detail: 'Pending',
        icon: Icons.medication_rounded,
        color: const Color(0xFF14B8A6),
        route: RoutesStr.pillReminder,
      ),
      12 => _GlanceSummaryData(
        title: 'Scanner',
        value: '${summary.scannedPageCount}',
        detail: 'Pages',
        icon: Icons.document_scanner_rounded,
        color: const Color(0xFF0EA5E9),
        route: RoutesStr.scannerGallery,
      ),
      _ => const _GlanceSummaryData(
        title: 'Summary',
        value: '0',
        detail: '',
        icon: Icons.widgets_rounded,
        color: Colors.grey,
        route: RoutesStr.home,
      ),
    };
  }

  static String _number(double value) => NumberFormat.compact().format(value);
}

class _GlanceSummaryItem extends StatelessWidget {
  const _GlanceSummaryItem({required this.data});

  final _GlanceSummaryData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: AppRadius.small,
      onTap: () => openResponsiveModule(context, data.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 31,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: data.color.withOpacity(isDark ? .22 : .11),
                    borderRadius: AppRadius.small,
                  ),
                  child: Icon(data.icon, size: 17, color: data.color),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.2),
            ),
            Text(
              data.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: data.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlanceSummaryData {
  const _GlanceSummaryData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final String route;
}
