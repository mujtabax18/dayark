import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/LoanModel.dart';
import '../../services/database_service.dart';
import '../../services/localDatabaseServices/LoanService.dart';

final loanServiceProvider = Provider<LoanService>((ref) {
  return LoanService(ref.read(databaseServiceProvider));
});

/// 0 = to receive, 1 = to pay, 2 = all.
final loanFilterProvider = StateProvider<int>((ref) => 2);

/// active/all/overdue/due_soon/settled.
final loanStatusFilterProvider = StateProvider<String>((ref) => 'active');
final loanSearchProvider = StateProvider<String>((ref) => '');
final loanSortProvider = StateProvider<String>((ref) => 'smart');

final loanListProvider =
    FutureProvider.autoDispose<List<LoanModel>>((ref) async {
  final service = ref.read(loanServiceProvider);
  final typeFilter = ref.watch(loanFilterProvider);
  final status = ref.watch(loanStatusFilterProvider);
  final query = ref.watch(loanSearchProvider);
  final sort = ref.watch(loanSortProvider);

  return service.getLoans(
    type: typeFilter == 2 ? null : typeFilter,
    statusFilter: status,
    query: query,
    sort: sort,
  );
});

final loanByIdProvider = FutureProvider.autoDispose
    .family<LoanModel?, int>((ref, loanId) async {
  return ref.read(loanServiceProvider).getLoanById(loanId);
});

final loanTransactionsProvider = FutureProvider.autoDispose
    .family<List<LoanTransaction>, int>((ref, loanId) async {
  return ref.read(loanServiceProvider).getTransactions(loanId);
});

final loanSnapshotProvider = FutureProvider.autoDispose
    .family<KhataAccountSnapshot, int>((ref, loanId) async {
  return ref.read(loanServiceProvider).getAccountSnapshot(loanId);
});

/// Kept for compatibility with the older loan widgets.
final loanPaidAmountProvider = FutureProvider.autoDispose
    .family<double, int>((ref, loanId) async {
  return ref.read(loanServiceProvider).getPaidAmount(loanId);
});

final loanSummaryProvider =
    FutureProvider.autoDispose<KhataDashboardSummary>((ref) async {
  return ref.read(loanServiceProvider).getDashboardSummary();
});

final loanMonthlyActivityProvider =
    FutureProvider.autoDispose<List<KhataMonthlyActivity>>((ref) async {
  return ref.read(loanServiceProvider).getMonthlyActivity(months: 6);
});

void refreshKhata(WidgetRef ref, {int? loanId}) {
  ref.invalidate(loanListProvider);
  ref.invalidate(loanSummaryProvider);
  ref.invalidate(loanMonthlyActivityProvider);
  if (loanId != null) {
    ref.invalidate(loanByIdProvider(loanId));
    ref.invalidate(loanTransactionsProvider(loanId));
    ref.invalidate(loanSnapshotProvider(loanId));
    ref.invalidate(loanPaidAmountProvider(loanId));
  }
}
