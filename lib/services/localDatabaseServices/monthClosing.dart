import 'dart:math';

import '../db/drift_database.dart';

import '../../models/MonthClosing.dart';
import '../database_service.dart';

class ClosingPreview {
  final int itemCount;
  final double totalIn;
  final double totalOut;

  const ClosingPreview({
    required this.itemCount,
    required this.totalIn,
    required this.totalOut,
  });

  double get net => totalIn - totalOut;
  bool get isEmpty => itemCount == 0;
}

class MonthClosingHelper {
  final DatabaseService _databaseService;

  MonthClosingHelper(this._databaseService);

  Future<List<MonthClosing>> getAllClosings() async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'month_closing',
      where: 'deleted_at IS NULL',
      orderBy: 'end_date DESC, id DESC',
    );
    return rows.map(MonthClosing.fromMap).toList();
  }

  /// Returns every currently open expense item.
  ///
  /// [startDate] and [endDate] remain in the method signature so existing UI
  /// code does not need to change. They no longer decide which rows belong to
  /// the closing. An item belongs to the current open month while its
  /// `closing_id` is NULL.
  Future<ClosingPreview> previewClosing({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _databaseService.database;
    final row = (await db.rawQuery(_openItemsTotalsSql)).first;

    return ClosingPreview(
      itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
      totalIn: (row['total_in'] as num?)?.toDouble() ?? 0,
      totalOut: (row['total_out'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Closes all active expense items whose `closing_id` is NULL.
  ///
  /// Dates are stored as closing metadata only. The actual stored range is
  /// derived from the oldest and newest included items, which keeps reports
  /// accurate even when an open item was entered with an older date.
  Future<MonthClosing> closeMonth({
    required String title,
    String description = '',
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();

    return db.transaction((txn) async {
      final totals = (await txn.rawQuery(_openItemsTotalsSql)).first;
      final itemCount = (totals['item_count'] as num?)?.toInt() ?? 0;

      if (itemCount == 0) {
        throw StateError('There are no open transactions to close.');
      }

      final totalIn = (totals['total_in'] as num?)?.toDouble() ?? 0;
      final totalOut = (totals['total_out'] as num?)?.toDouble() ?? 0;
      final actualStart = _normaliseStoredDate(
        totals['first_item_date'],
        fallback: startDate,
      );
      final actualEnd = _normaliseStoredDate(
        totals['last_item_date'],
        fallback: endDate,
      );
      final cleanTitle = title.trim().isEmpty
          ? 'Closing $actualStart to $actualEnd'
          : title.trim();

      final id = await txn.insert('month_closing', {
        'uuid': _newUuid(),
        'title': cleanTitle,
        'description': description.trim(),
        'start_date': actualStart,
        'end_date': actualEnd,
        'item_count': itemCount,
        'total_in': totalIn,
        'total_out': totalOut,
        'closed_at': now,
        'is_locked': 1,
        'creation_date': now,
        'updatation_date': now,
        'deleted_at': null,
      });

      // Membership is based only on closing_id. Do not restrict this update by
      // month start, today's date, or the date selected in the UI.
      final updated = await txn.rawUpdate('''
UPDATE expense_items
SET closing_id = ?, updatation_date = ?
WHERE deleted_at IS NULL
  AND closing_id IS NULL
''', [id, now]);

      if (updated != itemCount) {
        throw StateError(
          'Closing was cancelled because the open transaction count changed.',
        );
      }

      return MonthClosing(
        id: id,
        title: cleanTitle,
        description: description.trim(),
        startDate: actualStart,
        endDate: actualEnd,
        itemCount: itemCount,
        totalIn: totalIn,
        totalOut: totalOut,
        closedAt: DateTime.parse(now),
      );
    });
  }

  Future<int> reopenClosing(int closingId) async {
    final db = await _databaseService.database;
    final now = DateTime.now().toIso8601String();
    return db.transaction((txn) async {
      await txn.update(
        'expense_items',
        {'closing_id': null, 'updatation_date': now},
        where: 'closing_id = ? AND deleted_at IS NULL',
        whereArgs: [closingId],
      );
      return txn.update(
        'month_closing',
        {
          'is_locked': 0,
          'deleted_at': now,
          'updatation_date': now,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [closingId],
      );
    });
  }

  Future<MonthClosing?> getClosing(int id) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'month_closing',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : MonthClosing.fromMap(rows.first);
  }

  static const String _openItemsTotalsSql = '''
SELECT
  COUNT(*) AS item_count,
  COALESCE(SUM(CASE WHEN in_or_out = 'In' THEN price ELSE 0 END), 0) AS total_in,
  COALESCE(SUM(CASE WHEN in_or_out = 'Out' THEN price ELSE 0 END), 0) AS total_out,
  MIN(date) AS first_item_date,
  MAX(date) AS last_item_date
FROM expense_items
WHERE deleted_at IS NULL
  AND closing_id IS NULL
''';

  String _normaliseStoredDate(Object? value, {required DateTime fallback}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return _dateOnly(fallback);
    }

    // Most records already use YYYY-MM-DD. Parsing also handles ISO timestamps.
    final parsed = DateTime.tryParse(text);
    return parsed == null ? text : _dateOnly(parsed);
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _newUuid() {
    final random = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'closing-${DateTime.now().microsecondsSinceEpoch}-$random';
  }
}
