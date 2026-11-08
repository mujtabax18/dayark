import 'dart:math';

import '../db/drift_database.dart';

import '../../models/expense_category_data.dart';
import '../../models/ExpenseItem.dart';
import '../../models/ExpenseItemNode.dart';
import '../database_service.dart';
import 'package:metersystem/models/ExpenseReport.dart';

class ExpenseService {
  final DatabaseService _databaseService;

  ExpenseService(this._databaseService);

  Future<int> addExpensesTitle(
    String title1,
    String description, {
    String? color,
    int? iconCode,
    String iconFontFamily = 'MaterialIcons',
    bool hidden = false,
  }) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    return db.insert('expense_titles', {
      'uuid': _newUuid('category'),
      'title': title1.trim(),
      'description': description.trim(),
      'color': color ?? '#5C6BC0',
      'icon_code': iconCode ?? 57895,
      'icon_font_family': iconFontFamily,
      'hidden': hidden ? 1 : 0,
      'creation_date': now,
      'updatation_date': now,
      'deleted_at': null,
    });
  }

  Future<int> editExpensesTitle(
    int id,
    Map<String, dynamic> title,
  ) async {
    final db = await _databaseService.database;
    final values = Map<String, dynamic>.from(title);

    if (values.containsKey('hidden')) {
      final value = values['hidden'];
      values['hidden'] = value == true
          ? 1
          : value == false
              ? 0
              : value;
    }

    values.remove('id');
    values.remove('creation_date');
    values.remove('deleted_at');
    values['updatation_date'] = DateTime.now().toIso8601String();

    return db.update(
      'expense_titles',
      values,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
  }

  Future<int> deleteExpensesTitle(int id) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final closedCount = Sqflite.firstIntValue(await txn.rawQuery(
            '''
SELECT COUNT(*)
FROM expense_items
WHERE expense_id = ? AND deleted_at IS NULL AND closing_id IS NOT NULL
''',
            [id],
          )) ??
          0;
      if (closedCount > 0) {
        throw StateError(
          'This category contains closed transactions. Hide it instead, or reopen the related month before deleting it.',
        );
      }

      await txn.update(
        'expense_items',
        {'deleted_at': now, 'updatation_date': now},
        where: 'expense_id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      return txn.update(
        'expense_titles',
        {'deleted_at': now, 'updatation_date': now},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getAllExpensesTitles({
    bool includeHidden = true,
  }) async {
    final db = await _databaseService.database;
    return db.query(
      'expense_titles',
      where: includeHidden
          ? 'deleted_at IS NULL'
          : 'deleted_at IS NULL AND hidden = 0',
      orderBy: 'position ASC, title COLLATE NOCASE ASC',
    );
  }

  Future<Map<String, dynamic>?> getExpensesTitle(int id) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'expense_titles',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  Future<int> addExpenseItem({required ExpenseItem expenseItem}) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    final map = expenseItem.toMap()
      ..['uuid'] = expenseItem.uuid ?? _newUuid('item')
      ..['creation_date'] = now
      ..['updatation_date'] = now
      ..['closing_id'] = null
      ..['deleted_at'] = null;

    // A closing only snapshots existing rows. Every newly added transaction
    // belongs to the new active period, even when the selected transaction
    // date falls inside a previously closed date range.
    return db.insert('expense_items', map);
  }

  /// Edits the transaction in its existing period. Historical transactions
  /// keep their original `closing_id`, so opening a closed month allows that
  /// month to be corrected directly without reopening or merging it into the
  /// active period.
  Future<int> editExpenseItem(ExpenseItem expenseItem) async {
    if (expenseItem.id == null) return 0;
    final db = await _databaseService.database;
    final map = expenseItem.toMap(forUpdate: true)
      ..remove('uuid')
      ..remove('creation_date')
      ..remove('deleted_at')
      ..remove('closing_id')
      ..['updatation_date'] = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final closingIds = await _closingIdsForItems(
        txn,
        [expenseItem.id!],
      );
      final changed = await txn.update(
        'expense_items',
        map,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [expenseItem.id],
      );
      if (changed > 0) {
        await _refreshClosingSnapshots(txn, closingIds);
      }
      return changed;
    });
  }

  Future<int> deleteExpenseItem(int id) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final closingIds = await _closingIdsForItems(txn, [id]);
      final changed = await txn.update(
        'expense_items',
        {'deleted_at': now, 'updatation_date': now},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (changed > 0) {
        await _refreshClosingSnapshots(txn, closingIds);
      }
      return changed;
    });
  }

  Future<int> deleteExpenseItems(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await _databaseService.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      final closingIds = await _closingIdsForItems(txn, ids);
      final changed = await txn.update(
        'expense_items',
        {
          'deleted_at': now,
          'updatation_date': now,
        },
        where: 'id IN ($placeholders) AND deleted_at IS NULL',
        whereArgs: ids,
      );
      if (changed > 0) {
        await _refreshClosingSnapshots(txn, closingIds);
      }
      return changed;
    });
  }

  Future<int> moveExpenseItems(List<int> ids, int targetCategoryId) async {
    if (ids.isEmpty) return 0;
    final db = await _databaseService.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    return db.update(
      'expense_items',
      {
        'expense_id': targetCategoryId,
        'updatation_date': DateTime.now().toIso8601String(),
      },
      where: 'id IN ($placeholders) AND deleted_at IS NULL',
      whereArgs: ids,
    );
  }

  Future<void> updateGroceryInOUt(int id, String status) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      final closingIds = await _closingIdsForItems(txn, [id]);
      final changed = await txn.update(
        'expense_items',
        {
          'in_or_out': status,
          'updatation_date': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      if (changed > 0) {
        await _refreshClosingSnapshots(txn, closingIds);
      }
    });
  }

  Future<List<ExpenseItem>> getAllExpenseItems({
    String? date,
    double? price,
    String? inOrOut,
    int? id,
    int? expenseId,
    String closingId = 'latest',
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;
    final filter = _buildItemFilter(
      closingId: closingId,
      startDate: startDate,
      endDate: endDate,
      date: date,
      price: price,
      inOrOut: inOrOut,
      id: id,
      expenseId: expenseId,
    );

    final result = await db.query(
      'expense_items',
      where: filter.where,
      whereArgs: filter.args,
      orderBy: 'date DESC, id DESC',
    );

    return result.map(ExpenseItem.fromMap).toList();
  }

  Future<int?> getExpenseIdForItem(int itemId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'expense_items',
      columns: ['expense_id'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [itemId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return (result.first['expense_id'] as num?)?.toInt();
  }

  Future<Map<String, dynamic>?> getExpenseItem(int id) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'expense_items',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> fetchExpenseSummary({
    String closingId = 'latest',
    String? startDate,
    String? endDate,
  }) async {
    final db = await _databaseService.database;
    final filter = _buildItemFilter(
      alias: 'ei',
      closingId: closingId,
      startDate: startDate,
      endDate: endDate,
    );

    return db.rawQuery('''
SELECT
  et.id,
  et.title,
  et.description,
  et.color,
  et.icon_code,
  et.icon_font_family,
  et.hidden,
  et.position,
  COALESCE(SUM(CASE WHEN ei.in_or_out = 'In' THEN ei.price ELSE 0 END), 0) AS total_in,
  COALESCE(SUM(CASE WHEN ei.in_or_out = 'Out' THEN ei.price ELSE 0 END), 0) AS total_out,
  COUNT(ei.id) AS item_count
FROM expense_titles et
LEFT JOIN expense_items ei
  ON et.id = ei.expense_id
  AND ${filter.where}
WHERE et.deleted_at IS NULL
GROUP BY et.id
ORDER BY et.position ASC, et.title COLLATE NOCASE ASC
''', filter.args);
  }

  Future<List<ExpenseCategoryNode>> fetchExpenseSummaryTree({
    String closingId = 'latest',
    String? startDate,
    String? endDate,
  }) async {
    final summaries = await fetchExpenseSummary(
      closingId: closingId,
      startDate: startDate,
      endDate: endDate,
    );
    final items = await getAllExpenseItems(
      closingId: closingId,
      startDate: startDate,
      endDate: endDate,
    );

    final byCategory = <int, List<ExpenseItemNode>>{};
    for (final item in items) {
      byCategory.putIfAbsent(item.expenseId, () => []).add(
            ExpenseItemNode(
              id: item.id ?? 0,
              name: item.name,
              date: item.date.toIso8601String(),
              price: item.price ?? 0,
              inOrOut: item.inOrOut ?? 'Out',
              notes: item.notes,
              closingId: item.closingId,
            ),
          );
    }

    return summaries.map((row) {
      final id = (row['id'] as num).toInt();
      return ExpenseCategoryNode(
        id: id,
        title: row['title']?.toString() ?? '',
        color: row['color']?.toString(),
        iconCode: (row['icon_code'] as num?)?.toInt(),
        iconFontFamily: row['icon_font_family']?.toString(),
        hidden: (row['hidden'] as num?)?.toInt() ?? 0,
        totalIn: (row['total_in'] as num?)?.toDouble() ?? 0,
        totalOut: (row['total_out'] as num?)?.toDouble() ?? 0,
        items: byCategory[id] ?? [],
      );
    }).toList();
  }

  Future<List<ExpenseCategory>> fetchCategories({
    bool includeHidden = true,
  }) async {
    final rows = await getAllExpensesTitles(includeHidden: includeHidden);
    return rows
        .map(
          (e) => ExpenseCategory(
            id: (e['id'] as num).toInt(),
            title: e['title']?.toString() ?? '',
            colorHex: e['color']?.toString(),
            hidden: ((e['hidden'] as num?)?.toInt() ?? 0) == 1,
          ),
        )
        .toList();
  }

  Future<void> toggleCategory(int id, bool hidden) async {
    await editExpensesTitle(id, {'hidden': hidden});
  }

  Future<ExpenseReportData> fetchReportData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _databaseService.database;
    final start = _dateOnly(startDate);
    final endExclusive = _dateOnly(endDate.add(const Duration(days: 1)));
    final args = [start, endExclusive];

    final totalsRows = await db.rawQuery('''
SELECT
  COALESCE(SUM(CASE WHEN in_or_out = 'In' THEN price ELSE 0 END), 0) AS total_in,
  COALESCE(SUM(CASE WHEN in_or_out = 'Out' THEN price ELSE 0 END), 0) AS total_out,
  COUNT(*) AS item_count,
  MIN(date) AS min_date,
  MAX(date) AS max_date
FROM expense_items
WHERE deleted_at IS NULL AND date >= ? AND date < ?
''', args);

    final categoryRows = await db.rawQuery('''
SELECT
  et.id,
  et.title,
  et.color,
  et.icon_code,
  et.icon_font_family,
  et.hidden,
  COALESCE(SUM(CASE WHEN ei.in_or_out = 'In' THEN ei.price ELSE 0 END), 0) AS total_in,
  COALESCE(SUM(CASE WHEN ei.in_or_out = 'Out' THEN ei.price ELSE 0 END), 0) AS total_out,
  COUNT(ei.id) AS item_count
FROM expense_titles et
LEFT JOIN expense_items ei
  ON ei.expense_id = et.id
  AND ei.deleted_at IS NULL
  AND ei.date >= ? AND ei.date < ?
WHERE et.deleted_at IS NULL
GROUP BY et.id
HAVING COUNT(ei.id) > 0
ORDER BY total_out DESC, et.title COLLATE NOCASE ASC
''', args);

    final trendRows = await db.rawQuery('''
SELECT
  substr(date, 1, 7) AS period,
  COALESCE(SUM(CASE WHEN in_or_out = 'In' THEN price ELSE 0 END), 0) AS total_in,
  COALESCE(SUM(CASE WHEN in_or_out = 'Out' THEN price ELSE 0 END), 0) AS total_out
FROM expense_items
WHERE deleted_at IS NULL AND date >= ? AND date < ?
GROUP BY period
ORDER BY period ASC
''', args);

    final totals = totalsRows.first;
    final transactionCount = (totals['item_count'] as num?)?.toInt() ?? 0;
    final earliestDate =
        DateTime.tryParse(totals['min_date']?.toString() ?? '');
    final reportStart = startDate.year == 2000
        ? earliestDate == null
            ? endDate
            : DateTime(earliestDate.year, earliestDate.month, earliestDate.day)
        : startDate;
    final trendByPeriod = <String, Map<String, dynamic>>{
      for (final row in trendRows) row['period'].toString(): row,
    };
    final trend = <ExpenseTrendPoint>[];
    if (transactionCount > 0) {
      var cursor = DateTime(reportStart.year, reportStart.month);
      final lastMonth = DateTime(endDate.year, endDate.month);
      while (!cursor.isAfter(lastMonth)) {
        final key = '${cursor.year.toString().padLeft(4, '0')}-'
            '${cursor.month.toString().padLeft(2, '0')}';
        final row = trendByPeriod[key];
        trend.add(
          ExpenseTrendPoint(
            label: key,
            periodStart: cursor,
            totalIn: (row?['total_in'] as num?)?.toDouble() ?? 0,
            totalOut: (row?['total_out'] as num?)?.toDouble() ?? 0,
          ),
        );
        cursor = DateTime(cursor.year, cursor.month + 1);
      }
    }

    return ExpenseReportData(
      startDate: reportStart,
      endDate: endDate,
      totalIn: (totals['total_in'] as num?)?.toDouble() ?? 0,
      totalOut: (totals['total_out'] as num?)?.toDouble() ?? 0,
      transactionCount: transactionCount,
      categories: categoryRows
          .map(
            (row) => ExpenseCategoryReport(
              id: (row['id'] as num).toInt(),
              title: row['title']?.toString() ?? '',
              colorHex: row['color']?.toString(),
              iconCode: (row['icon_code'] as num?)?.toInt(),
              iconFontFamily: row['icon_font_family']?.toString(),
              hidden: ((row['hidden'] as num?)?.toInt() ?? 0) == 1,
              totalIn: (row['total_in'] as num?)?.toDouble() ?? 0,
              totalOut: (row['total_out'] as num?)?.toDouble() ?? 0,
              itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(),
      trend: trend,
    );
  }

  _FilterParts _buildItemFilter({
    String alias = '',
    String closingId = 'latest',
    String? startDate,
    String? endDate,
    String? date,
    double? price,
    String? inOrOut,
    int? id,
    int? expenseId,
  }) {
    final prefix = alias.isEmpty ? '' : '$alias.';
    final conditions = <String>['${prefix}deleted_at IS NULL'];
    final args = <dynamic>[];

    final normalizedClosing = closingId.toLowerCase();
    if (normalizedClosing == 'latest') {
      conditions.add('${prefix}closing_id IS NULL');
    } else if (normalizedClosing != 'all') {
      final parsed = int.tryParse(closingId);
      if (parsed != null) {
        conditions.add('${prefix}closing_id = ?');
        args.add(parsed);
      }
    }

    if (date != null && date.isNotEmpty) {
      conditions.add('${prefix}date >= ? AND ${prefix}date < ?');
      args.add(date);
      args.add(_nextDateString(date));
    } else {
      if (startDate != null && startDate.isNotEmpty) {
        conditions.add('${prefix}date >= ?');
        args.add(startDate);
      }
      if (endDate != null && endDate.isNotEmpty) {
        conditions.add('${prefix}date < ?');
        args.add(_nextDateString(endDate));
      }
    }

    if (price != null) {
      conditions.add('${prefix}price = ?');
      args.add(price);
    }
    if (inOrOut != null) {
      conditions.add('${prefix}in_or_out = ?');
      args.add(inOrOut);
    }
    if (id != null) {
      conditions.add('${prefix}id = ?');
      args.add(id);
    }
    if (expenseId != null) {
      conditions.add('${prefix}expense_id = ?');
      args.add(expenseId);
    }

    return _FilterParts(conditions.join(' AND '), args);
  }

  Future<Set<int>> _closingIdsForItems(
    DatabaseExecutor db,
    List<int> ids,
  ) async {
    if (ids.isEmpty) return <int>{};
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
SELECT DISTINCT closing_id
FROM expense_items
WHERE id IN ($placeholders)
  AND deleted_at IS NULL
  AND closing_id IS NOT NULL
''',
      ids,
    );
    return rows
        .map((row) => (row['closing_id'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
  }

  Future<void> _refreshClosingSnapshots(
    DatabaseExecutor db,
    Iterable<int> closingIds,
  ) async {
    final now = DateTime.now().toIso8601String();
    for (final closingId in closingIds.toSet()) {
      final totals = (await db.rawQuery(
        '''
SELECT
  COUNT(*) AS item_count,
  COALESCE(SUM(CASE WHEN in_or_out = 'In' THEN price ELSE 0 END), 0) AS total_in,
  COALESCE(SUM(CASE WHEN in_or_out = 'Out' THEN price ELSE 0 END), 0) AS total_out,
  MIN(date) AS first_item_date,
  MAX(date) AS last_item_date
FROM expense_items
WHERE closing_id = ?
  AND deleted_at IS NULL
''',
        [closingId],
      ))
          .first;

      final itemCount = (totals['item_count'] as num?)?.toInt() ?? 0;
      final values = <String, dynamic>{
        'item_count': itemCount,
        'total_in': (totals['total_in'] as num?)?.toDouble() ?? 0,
        'total_out': (totals['total_out'] as num?)?.toDouble() ?? 0,
        'updatation_date': now,
      };
      if (itemCount > 0) {
        values['start_date'] = _normaliseStoredDate(totals['first_item_date']);
        values['end_date'] = _normaliseStoredDate(totals['last_item_date']);
      }

      await db.update(
        'month_closing',
        values,
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [closingId],
      );
    }
  }

  String? _normaliseStoredDate(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    return parsed == null ? text : _dateOnly(parsed);
  }

  String _nextDateString(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '$value\uFFFF';
    return _dateOnly(parsed.add(const Duration(days: 1)));
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _newUuid(String prefix) {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}

class _FilterParts {
  final String where;
  final List<dynamic> args;

  const _FilterParts(this.where, this.args);
}
