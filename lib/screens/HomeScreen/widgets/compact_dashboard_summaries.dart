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

class CompactDashboardSummaries extends ConsumerWidget {
  const CompactDashboardSummaries({
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
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                hasVisibleSelection
                    ? 'Summaries appear when records are available.'
                    : 'Choose summary cards in Home settings.',
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          final columns = constraints.maxWidth >= 1120 ? 5 : 4;
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
                    height: 96,
                    child: _CompactSummaryCard(
                      data: _dataFor(
                        id,
                        summary,
                        exactExpenses,
                        currency,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        }

        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ids.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) => SizedBox(
              width: 178,
              child: _CompactSummaryCard(
                data: _dataFor(
                  ids[index],
                  summary,
                  exactExpenses,
                  currency,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _CompactSummaryData _dataFor(
    int id,
    DashboardSummary summary,
    HomeExpenseSummary? exactExpenses,
    CurrencySetting currency,
  ) {
    return switch (id) {
      1 => _CompactSummaryData(
          title: 'Meter usage',
          value: _number(summary.meters.totalUnitsUsed),
          detail: '${summary.meters.items.length} active meter(s)',
          icon: Icons.electric_meter_outlined,
          color: const Color(0xFF4F46E5),
          route: RoutesStr.meterList,
        ),
      2 => _CompactSummaryData(
          title: 'Grocery',
          value: '${summary.grocery.totalRemaining} remaining',
          detail:
              '${summary.grocery.pendingItems} items • ${summary.grocery.pendingChores} chores',
          icon: Icons.shopping_basket_outlined,
          color: const Color(0xFF22C55E),
          route: RoutesStr.grocery,
        ),
      3 => _CompactSummaryData(
          title: 'Expenses',
          value: currency.formatCompact(
            exactExpenses?.remaining ?? summary.expenses.remaining,
          ),
          detail: '${currency.formatCompact(
            exactExpenses?.expense ?? summary.expenses.expense,
          )} spent',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFFF43F5E),
          route: RoutesStr.expense,
        ),
      5 => _CompactSummaryData(
          title: 'Diary',
          value: '${summary.diaryEntryCount} entries',
          detail: 'Personal diary',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFFEC4899),
          route: RoutesStr.moodTracker,
        ),
      6 => _CompactSummaryData(
          title: 'Habits',
          value: '${summary.habits.completed}/${summary.habits.total} done',
          detail: '${(summary.habits.completionRate * 100).round()}% today',
          icon: Icons.track_changes_rounded,
          color: const Color(0xFF8B5CF6),
          route: RoutesStr.habits,
        ),
      8 => _CompactSummaryData(
          title: 'Invoices',
          value: '${summary.invoiceCount}',
          detail: 'Saved invoices',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFF6366F1),
          route: RoutesStr.invoices,
        ),
      9 => _CompactSummaryData(
          title: 'Digital Khata',
          value: currency.formatCompact(summary.loans.toReceive),
          detail: '${summary.loans.activeAccounts} active account(s)',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFF0891B2),
          route: RoutesStr.loans,
        ),
      10 => _CompactSummaryData(
          title: 'Media Studio',
          value: '${summary.mediaFileCount} files',
          detail: 'Local media',
          icon: Icons.perm_media_rounded,
          color: const Color(0xFFE11D48),
          route: RoutesStr.multimedia,
        ),
      11 => _CompactSummaryData(
          title: 'Pill reminder',
          value: '${summary.pills.pending} pending',
          detail: '${summary.pills.taken} taken • ${summary.pills.missed} missed',
          icon: Icons.medication_outlined,
          color: const Color(0xFF14B8A6),
          route: RoutesStr.pillReminder,
        ),
      12 => _CompactSummaryData(
          title: 'Doc Scanner',
          value: '${summary.scannedPageCount} pages',
          detail: 'Scanned locally',
          icon: Icons.document_scanner_rounded,
          color: const Color(0xFF0EA5E9),
          route: RoutesStr.scannerGallery,
        ),
      _ => const _CompactSummaryData(
          title: '',
          value: '',
          detail: '',
          icon: Icons.widgets_outlined,
          color: Colors.grey,
          route: RoutesStr.home,
        ),
    };
  }


  static String _number(double value) => NumberFormat.compact().format(value);
}

class _CompactSummaryCard extends StatelessWidget {
  const _CompactSummaryCard({required this.data});

  final _CompactSummaryData data;

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
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(isDark ? .22 : .11),
                  borderRadius: AppRadius.small,
                ),
                child: Icon(data.icon, size: 17, color: data.color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 1),
          Text(
            data.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompactSummaryData {
  const _CompactSummaryData({
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
