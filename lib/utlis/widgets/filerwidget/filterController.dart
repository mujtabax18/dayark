import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/FilterModel.dart';
import '../../../screens/Expenses/controller/ExpensesController.dart';
import '../../../screens/Grocery/Grocery/controller/grocery_controller.dart';
import '../../../services/localDatabaseServices/filterService.dart';
import 'package:flutter_riverpod/legacy.dart';

class FilterNotifier extends StateNotifier<Filter?> {
  final FilterService _filterService;
  final String tableName;

  FilterNotifier(this._filterService, this.tableName) : super(null) {
    loadFilter(tableName); // Load filter on initialization
  }

  Future<void> loadFilter(String tableName) async {
    state = await _filterService.getFilter(tableName);
  }

  Future<void> updateFilter(
      String tableName, String? startDate, String? endDate) async {
    if (startDate != null &&
        endDate != null &&
        startDate.compareTo(endDate) > 0) {
      endDate = ''; // Reset end date if invalid
    }
    final filter = Filter(
        tableName: tableName,
        startDate: startDate ?? '',
        endDate: endDate ?? '');
    await _filterService.saveFilter(filter);
    state = filter;
  }
}

final filterProvider =
    StateNotifierProvider.family<FilterNotifier, Filter?, String>(
        (ref, tableName) {
  return FilterNotifier(FilterService(databaseService), tableName);
});
