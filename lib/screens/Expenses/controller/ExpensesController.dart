import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/ExpenseItem.dart';
import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/ExpenseService.dart';
import '../../HomeScreen/controller/dashboard_provider.dart';
import 'ExpenseNotiferController.dart';

final dbExpenseServiceProvider = Provider<ExpenseService>((ref) {
  return ExpenseService(ref.watch(databaseServiceProvider));
});

final expenseItemFilterClosingIdProvider =
    NotifierProvider<ExpenseItemFilterClosingIdNotifier, String>(
  ExpenseItemFilterClosingIdNotifier.new,
);

final expenseItemFilterStartDateProvider =
    NotifierProvider<ExpenseItemFilterStartDateNotifier, String?>(
  ExpenseItemFilterStartDateNotifier.new,
);

final expenseItemFilterEndDateProvider =
    NotifierProvider<ExpenseItemFilterEndDate, String?>(
  ExpenseItemFilterEndDate.new,
);

final showHiddenExpenseCategoriesProvider =
    NotifierProvider<ShowHiddenExpenseCategoriesNotifier, bool>(
  ShowHiddenExpenseCategoriesNotifier.new,
);

final expenseSummaryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(dbExpenseServiceProvider);
  return service.fetchExpenseSummary(
    closingId: ref.watch(expenseItemFilterClosingIdProvider),
    startDate: ref.watch(expenseItemFilterStartDateProvider),
    endDate: ref.watch(expenseItemFilterEndDateProvider),
  );
});

final expenseItemsProvider =
    FutureProvider.family<List<ExpenseItem>, int>((ref, expenseId) async {
  final service = ref.watch(dbExpenseServiceProvider);
  return service.getAllExpenseItems(
    expenseId: expenseId,
    closingId: ref.watch(expenseItemFilterClosingIdProvider),
    startDate: ref.watch(expenseItemFilterStartDateProvider),
    endDate: ref.watch(expenseItemFilterEndDateProvider),
  );
});

final expenseCategoryProvider =
    FutureProvider.family<Map<String, dynamic>?, int>((ref, id) {
  return ref.watch(dbExpenseServiceProvider).getExpensesTitle(id);
});

final expenseCategoriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(dbExpenseServiceProvider).getAllExpensesTitles();
});

final deleteExpenseTitleProvider =
    Provider.family<Future<void>, int>((ref, titleId) async {
  await ref.read(dbExpenseServiceProvider).deleteExpensesTitle(titleId);
  ref.invalidate(expenseSummaryProvider);
  ref.invalidate(expenseCategoriesProvider);
  ref.invalidate(homeExpenseSummaryProvider);
  ref.invalidate(homeDashboardProvider);
});

final deleteExpenseItemProvider =
    Provider.family<Future<void>, int>((ref, itemId) async {
  final service = ref.read(dbExpenseServiceProvider);
  final categoryId = await service.getExpenseIdForItem(itemId);
  await service.deleteExpenseItem(itemId);
  ref.invalidate(expenseSummaryProvider);
  ref.invalidate(homeExpenseSummaryProvider);
  ref.invalidate(homeDashboardProvider);
  if (categoryId != null) ref.invalidate(expenseItemsProvider(categoryId));
});

void invalidateExpenseData(WidgetRef ref, {int? categoryId}) {
  ref.invalidate(expenseSummaryProvider);
  ref.invalidate(expenseCategoriesProvider);
  ref.invalidate(homeExpenseSummaryProvider);
  ref.invalidate(homeDashboardProvider);
  // Invalidate every active family instance after restore, closing, or bulk
  // operations; callers may not know all categories affected by the change.
  ref.invalidate(expenseItemsProvider);
  ref.invalidate(expenseCategoryProvider);
  if (categoryId != null) {
    // Retain targeted invalidation for compatibility with existing callers.
    ref.invalidate(expenseItemsProvider(categoryId));
    ref.invalidate(expenseCategoryProvider(categoryId));
  }
}
