import 'package:metersystem/screens/Expenses/controller/ExpensesController.dart';
import '../db/drift_database.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/FilterModel.dart';
import '../../utlis/widgets/filerwidget/filterController.dart';
import '../database_service.dart';

class FilterService {
  FilterService(this._databaseService);
  final DatabaseService _databaseService;

  Future<void> saveFilter(Filter filter) async {
    final db = await _databaseService.database;

    // Check if an entry exists for the given tableName
    final existing = await db.query(
      'table_filters',
      where: 'table_name = ?',
      whereArgs: [filter.tableName],
    );

    final data = {
      'table_name': filter.tableName,
      'start_date': filter.startDate,
      'end_date': filter.endDate,
    };

    if (existing.isNotEmpty) {
      // Update the existing filter (exclude 'id' field)
      await db.update(
        'table_filters',
        data,
        where: 'table_name = ?',
        whereArgs: [filter.tableName],
      );
    } else {
      // Insert a new filter entry
      await db.insert(
        'table_filters',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<Filter?> getFilter(String tableName) async {
    final db = await _databaseService.database;
    final result = await db.query('table_filters', where: 'table_name = ?', whereArgs: [tableName]);
    return result.isNotEmpty ? Filter.fromMap(result.first) : null;
  }
}
