// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:metersystem/screens/Expenses/controller/ExpensesController.dart';
// import 'package:metersystem/services/database_service.dart';
// import '../../../services/db/drift_database.dart';
//
// import '../../../services/localDatabaseServices/monthClosing.dart';
// import 'package:flutter_riverpod/legacy.dart';
//
// class MonthClosingNotifier extends StateNotifier<AsyncValue<void>> {
//   MonthClosingNotifier() : super(const AsyncValue.data(null));
//
//   Future<void> closeMonth(
//       String title, String description, String tableName) async {
//     try {
//       state = const AsyncValue.loading();
//
//       final monthClosingHelper = MonthClosingHelper(databaseService);
//
//       String currentDate = DateTime.now().toIso8601String();
//
//       await monthClosingHelper.insertClosing(
//           title, description, currentDate, tableName);
//       state = const AsyncValue.data(null);
//     } catch (e) {
//       state = AsyncValue.error(e, StackTrace.current);
//     }
//   }
// }
//
// final monthClosingProvider =
//     StateNotifierProvider<MonthClosingNotifier, AsyncValue<void>>(
//   (ref) => MonthClosingNotifier(),
// );
export '../../../controller/monthclosingController.dart';
