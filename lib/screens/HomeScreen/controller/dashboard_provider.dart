import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/dashboard_summary.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/ExpenseService.dart';
import '../../meter/MeterList/controller/meter_provider.dart';

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.watch(databaseServiceProvider));
});

final homeDashboardProvider = FutureProvider<DashboardSummary>((ref) {
  // Meter mutations can happen from the meter list, detail screen, or quick
  // actions. Watching the shared revision keeps every dashboard meter summary
  // in sync immediately after a baseline/reading/tariff change.
  ref.watch(meterDataRevisionProvider);
  return ref.watch(dashboardServiceProvider).loadSummary();
});

/// Expense totals used by the home screen.
///
/// This intentionally uses the same `closing_id IS NULL` summary query as the
/// expense screen's default "Open period" view. It prevents the dashboard from
/// mixing calendar-month data with the application's closing-based periods.
final homeExpenseSummaryProvider =
    FutureProvider<HomeExpenseSummary>((ref) async {
  final service = ExpenseService(ref.watch(databaseServiceProvider));
  final rows = await service.fetchExpenseSummary(closingId: 'latest');

  var income = 0.0;
  var expense = 0.0;
  var transactionCount = 0;
  var categoryCount = 0;

  for (final row in rows) {
    income += (row['total_in'] as num?)?.toDouble() ?? 0;
    expense += (row['total_out'] as num?)?.toDouble() ?? 0;
    final count = (row['item_count'] as num?)?.toInt() ?? 0;
    transactionCount += count;
    if (count > 0) categoryCount++;
  }

  return HomeExpenseSummary(
    income: income,
    expense: expense,
    transactionCount: transactionCount,
    categoryCount: categoryCount,
  );
});

class HomeExpenseSummary {
  final double income;
  final double expense;
  final int transactionCount;
  final int categoryCount;

  const HomeExpenseSummary({
    required this.income,
    required this.expense,
    required this.transactionCount,
    required this.categoryCount,
  });

  double get remaining => income - expense;
}
