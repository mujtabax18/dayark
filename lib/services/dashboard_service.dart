import 'package:flutter/foundation.dart';

import 'db/drift_database.dart';

import '../models/dashboard_summary.dart';
import '../models/habit_progress.dart';
import 'database_service.dart';
import 'localDatabaseServices/GroceryService.dart';
import 'localDatabaseServices/LoanService.dart';
import 'localDatabaseServices/PillReminder_Service.dart';
import 'localDatabaseServices/habitTrackerService.dart';

class DashboardService {
  DashboardService(this.databaseService);

  final DatabaseService databaseService;

  Future<DashboardSummary> loadSummary() async {
    final db = await databaseService.database;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final month = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';

    // Treat every module summary independently. A freshly cleared database is
    // a valid empty state, and one feature should never make the entire Home
    // dashboard fail while its tables/controllers are being reinitialized.
    final expenseFuture = _guard(
      () => _loadExpenseSummary(db, month),
      const ExpenseHomeSummary(
        income: 0,
        expense: 0,
        categoryCount: 0,
        transactionCount: 0,
      ),
    );
    final meterFuture = _guard(
      () => _loadMeterSummary(db),
      const MeterHomeSummary(items: [], totalUnitsUsed: 0),
    );
    final habitFuture = _guard(
      () => _loadHabitSummary(now),
      const HabitHomeSummary(items: []),
    );
    final groceryFuture = _guard(
      () => _loadGrocerySummary(db, now),
      const GroceryHomeSummary(
        planCount: 0,
        pendingItems: 0,
        pendingChores: 0,
        overdue: 0,
        entries: [],
      ),
    );
    final pillFuture = _guard(
      () => _loadPillSummary(now, today),
      const PillHomeSummary(
        pending: 0,
        taken: 0,
        missed: 0,
        skipped: 0,
        occurrences: [],
      ),
    );
    final loanFuture = _guard(
      _loadLoanSummary,
      const LoanHomeSummary(
        toReceive: 0,
        toPay: 0,
        overdueAmount: 0,
        overdueAccounts: 0,
        activeAccounts: 0,
        settledAccounts: 0,
        collectedThisMonth: 0,
        paidThisMonth: 0,
      ),
    );
    final countFuture = _guard(
      () => Future.wait<int>([
        _int(db, 'SELECT COUNT(*) FROM invoices'),
        _int(db, 'SELECT COUNT(*) FROM media_files WHERE is_deleted = 0'),
        _int(db, 'SELECT COUNT(*) FROM scans'),
        _int(db, 'SELECT COUNT(*) FROM mood_entries'),
      ]),
      const <int>[0, 0, 0, 0],
    );

    final results = await Future.wait<dynamic>([
      expenseFuture,
      meterFuture,
      habitFuture,
      groceryFuture,
      pillFuture,
      loanFuture,
      countFuture,
    ]);
    final counts = results[6] as List<int>;

    return DashboardSummary(
      expenses: results[0] as ExpenseHomeSummary,
      meters: results[1] as MeterHomeSummary,
      habits: results[2] as HabitHomeSummary,
      grocery: results[3] as GroceryHomeSummary,
      pills: results[4] as PillHomeSummary,
      loans: results[5] as LoanHomeSummary,
      invoiceCount: counts[0],
      mediaFileCount: counts[1],
      scannedPageCount: counts[2],
      diaryEntryCount: counts[3],
    );
  }

  Future<void> markHabitComplete(int habitId) async {
    final now = DateTime.now();
    await HabitTrackerService(databaseService).recordProgress(
      HabitProgress(
        habitId: habitId,
        date: now,
        isCompleted: true,
        status: 'completed',
        updatedAt: now,
      ),
    );
  }

  Future<void> completeGroceryEntry(GroceryHomeEntry entry) async {
    final service = GroceryService(databaseService);
    if (entry.isChore) {
      await service.updateHouseholdChoreStatus(entry.id, 'completed');
    } else {
      await service.updateGroceryItemStatus(
        entry.id,
        1,
        DateTime.now().toIso8601String(),
      );
    }
  }

  Future<void> markPillTaken(int occurrenceId) async {
    final service = PillReminderService(databaseService);
    try {
      await service.markOccurrence(
        occurrenceId: occurrenceId,
        status: 'TAKEN',
      );
    } finally {
      service.dispose();
    }
  }

  Future<ExpenseHomeSummary> _loadExpenseSummary(
    Database db,
    String month,
  ) async {
    final rows = await _safeRows(db, '''
SELECT
  COALESCE(SUM(CASE WHEN in_or_out = 'In' THEN price ELSE 0 END), 0) AS income,
  COALESCE(SUM(CASE WHEN in_or_out = 'Out' THEN price ELSE 0 END), 0) AS expense,
  COUNT(*) AS transaction_count
FROM expense_items
WHERE deleted_at IS NULL AND substr(date, 1, 7) = ?
''', [month]);
    final row = rows.isEmpty ? const <String, Object?>{} : rows.first;
    final categoryCount = await _int(
      db,
      'SELECT COUNT(*) FROM expense_titles WHERE deleted_at IS NULL',
    );
    return ExpenseHomeSummary(
      income: _asDouble(row['income']),
      expense: _asDouble(row['expense']),
      categoryCount: categoryCount,
      transactionCount: _asInt(row['transaction_count']),
    );
  }

  Future<MeterHomeSummary> _loadMeterSummary(Database db) async {
    final rows = await _safeRows(db, '''
SELECT
  m.id,
  m.name,
  m.baseline,
  m.unit_label,
  m.color_value,
  m.icon_key,
  (
    SELECT r.value
    FROM readings r
    WHERE r.meter_id = m.id
      AND (
        a.date IS NULL OR
        datetime(r.date) >= datetime(a.date)
      )
    ORDER BY datetime(r.date) DESC, r.id DESC
    LIMIT 1
  ) AS latest_reading
FROM meters m
LEFT JOIN meter_baseline_anchors a ON a.meter_id = m.id
WHERE m.is_active = 1
  AND m.baseline IS NOT NULL
  AND EXISTS (
    SELECT 1 FROM readings reading_exists
    WHERE reading_exists.meter_id = m.id
  )
ORDER BY m.name COLLATE NOCASE ASC
''');

    final items = rows.map((row) {
      final baseline = _asNullableDouble(row['baseline']);
      final latest = _asNullableDouble(row['latest_reading']);
      final used = baseline == null || latest == null
          ? 0.0
          : (latest - baseline).clamp(0, double.infinity).toDouble();
      return MeterHomeItem(
        id: _asInt(row['id']),
        name: row['name']?.toString() ?? 'Meter',
        baseline: baseline,
        latestReading: latest,
        unitsUsed: used,
        unitLabel: row['unit_label']?.toString() ?? 'units',
        colorValue: _asInt(row['color_value'], fallback: 0xFF4F46E5),
        iconKey: row['icon_key']?.toString() ?? 'electricity',
      );
    }).toList(growable: false);

    return MeterHomeSummary(
      items: items,
      totalUnitsUsed: items.fold<double>(
        0,
        (total, item) => total + item.unitsUsed,
      ),
    );
  }

  Future<HabitHomeSummary> _loadHabitSummary(DateTime now) async {
    try {
      final habits = await HabitTrackerService(databaseService).getAllHabits();
      final items = habits
          .where((habit) => habit.isActive && habit.isScheduledOn(now))
          .map((habit) {
        final progress = habit.progressFor(now);
        return HabitHomeItem(
          id: habit.id!,
          title: habit.title,
          description: habit.description,
          category: habit.category,
          deadlineHour: habit.deadlineHour,
          deadlineMinute: habit.deadlineMinute,
          isCompleted: progress?.isCompleted == true,
          canComplete: progress?.isCompleted != true && habit.canUpdate(now),
          currentStreak: habit.currentStreak,
          colorValue: habit.colorValue,
          iconCode: habit.iconCode,
        );
      }).toList(growable: false)
        ..sort((a, b) {
          if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
          final left = (a.deadlineHour * 60) + a.deadlineMinute;
          final right = (b.deadlineHour * 60) + b.deadlineMinute;
          return left.compareTo(right);
        });
      return HabitHomeSummary(items: items);
    } catch (_) {
      return const HabitHomeSummary(items: []);
    }
  }

  Future<GroceryHomeSummary> _loadGrocerySummary(
    Database db,
    DateTime now,
  ) async {
    final service = GroceryService(databaseService);
    Map<String, dynamic> dashboard = const {};
    try {
      dashboard = await service.getDashboardSummary();
    } catch (_) {}

    final rows = await _safeRows(db, '''
SELECT *
FROM (
  SELECT
    gi.id,
    gi.grocery_id,
    gi.name AS title,
    gi.quantity,
    gi.unit,
    gi.priority,
    gi.due_at,
    gt.title AS plan_title,
    'item' AS entry_kind
  FROM grocery_items gi
  LEFT JOIN grocery_titles gt ON gt.id = gi.grocery_id
  WHERE gi.status = 0

  UNION ALL

  SELECT
    hc.id,
    NULL AS grocery_id,
    hc.title,
    NULL AS quantity,
    NULL AS unit,
    hc.priority,
    hc.due_at,
    hc.chore_type AS plan_title,
    'chore' AS entry_kind
  FROM household_chores hc
  WHERE hc.status NOT IN ('completed', 'skipped')
)
ORDER BY
  CASE priority WHEN 'urgent' THEN 0 WHEN 'high' THEN 1 WHEN 'normal' THEN 2 ELSE 3 END,
  CASE WHEN due_at IS NULL OR due_at = '' THEN 1 ELSE 0 END,
  due_at ASC,
  id DESC
''');

    final entries = rows.map((row) {
      final kind = row['entry_kind']?.toString() ?? 'item';
      final dueAt = DateTime.tryParse(row['due_at']?.toString() ?? '');
      final quantity = _asNullableDouble(row['quantity']);
      final unit = row['unit']?.toString();
      final plan = row['plan_title']?.toString();
      final quantityText = quantity == null
          ? null
          : '${_formatNumber(quantity)} ${unit ?? ''}'.trim();
      final subtitleParts = <String>[
        if (quantityText != null && quantityText.isNotEmpty) quantityText,
        if (plan != null && plan.trim().isNotEmpty) plan.trim(),
      ];
      return GroceryHomeEntry(
        id: _asInt(row['id']),
        kind: kind,
        title: row['title']?.toString() ?? '',
        subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' • '),
        priority: row['priority']?.toString() ?? 'normal',
        isOverdue: dueAt != null && dueAt.isBefore(now),
        groceryId: row['grocery_id'] == null
            ? null
            : _asInt(row['grocery_id']),
      );
    }).toList(growable: false);

    return GroceryHomeSummary(
      planCount: _asInt(dashboard['plans']),
      pendingItems: _asInt(dashboard['pending_items']),
      pendingChores: _asInt(dashboard['pending_chores']),
      overdue: _asInt(dashboard['overdue']),
      entries: entries,
    );
  }

  Future<PillHomeSummary> _loadPillSummary(
    DateTime now,
    String today,
  ) async {
    final service = PillReminderService(databaseService);
    try {
      await service.ensureOccurrencesGenerated(
        throughDate: now.add(const Duration(days: 7)),
      );
      await service.refreshMissedOccurrences();
      final results = await Future.wait<dynamic>([
        service.getOccurrencesForDate(today),
        service.getStatsForExactDate(today),
      ]);
      final rows = List<Map<String, dynamic>>.from(results[0] as List);
      final stats = Map<String, int>.from(results[1] as Map);
      final occurrences = rows.map((row) {
        final scheduledDate = row['scheduled_date']?.toString() ?? today;
        final scheduledTime = row['scheduled_time']?.toString() ?? '00:00';
        final scheduled = _tryScheduledDateTime(scheduledDate, scheduledTime);
        final dosageValue = _asNullableDouble(row['dosage_value']);
        final dosageType = row['dosage_type_name']?.toString();
        final doseQuantity = _asNullableDouble(row['dose_quantity']);
        final dosageParts = <String>[
          if (dosageValue != null) _formatNumber(dosageValue),
          if (dosageType != null && dosageType.trim().isNotEmpty)
            dosageType.trim(),
          if (doseQuantity != null && doseQuantity != 1)
            '× ${_formatNumber(doseQuantity)}',
        ];
        final status = row['status']?.toString() ?? 'PENDING';
        return PillHomeOccurrence(
          id: _asInt(row['id']),
          pillName: row['pill_name']?.toString() ?? 'Medicine',
          scheduledDate: scheduledDate,
          scheduledTime: scheduledTime,
          status: status,
          colorHex: row['color_hex']?.toString() ?? '#6C63FF',
          canTake: status != 'TAKEN' &&
              scheduled != null &&
              !scheduled.isAfter(now),
          dosage: dosageParts.isEmpty ? null : dosageParts.join(' '),
          notes: row['notes']?.toString(),
        );
      }).toList(growable: false);

      return PillHomeSummary(
        pending: stats['PENDING'] ?? 0,
        taken: stats['TAKEN'] ?? 0,
        missed: stats['MISSED'] ?? 0,
        skipped: stats['SKIPPED'] ?? 0,
        occurrences: occurrences,
      );
    } catch (_) {
      return const PillHomeSummary(
        pending: 0,
        taken: 0,
        missed: 0,
        skipped: 0,
        occurrences: [],
      );
    } finally {
      service.dispose();
    }
  }

  Future<LoanHomeSummary> _loadLoanSummary() async {
    try {
      final summary = await LoanService(databaseService).getDashboardSummary();
      return LoanHomeSummary(
        toReceive: summary.toReceive,
        toPay: summary.toPay,
        overdueAmount: summary.overdueAmount,
        overdueAccounts: summary.overdueAccounts,
        activeAccounts: summary.activeAccounts,
        settledAccounts: summary.settledAccounts,
        collectedThisMonth: summary.collectedThisMonth,
        paidThisMonth: summary.paidThisMonth,
      );
    } catch (_) {
      return const LoanHomeSummary(
        toReceive: 0,
        toPay: 0,
        overdueAmount: 0,
        overdueAccounts: 0,
        activeAccounts: 0,
        settledAccounts: 0,
        collectedThisMonth: 0,
        paidThisMonth: 0,
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() loader, T fallback) async {
    try {
      return await loader();
    } catch (error, stackTrace) {
      debugPrint('Dashboard summary section failed: $error\n$stackTrace');
      return fallback;
    }
  }

  Future<int> _int(
    Database db,
    String sql, [
    List<Object?>? arguments,
  ]) async {
    try {
      return Sqflite.firstIntValue(await db.rawQuery(sql, arguments)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, Object?>>> _safeRows(
    Database db,
    String sql, [
    List<Object?>? arguments,
  ]) async {
    try {
      return await db.rawQuery(sql, arguments);
    } catch (_) {
      return const [];
    }
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  DateTime? _tryScheduledDateTime(String date, String time) {
    try {
      final dateParts = date.split('-').map(int.parse).toList();
      final timeParts = time.split(':').map(int.parse).toList();
      return DateTime(
        dateParts[0],
        dateParts[1],
        dateParts[2],
        timeParts[0],
        timeParts[1],
      );
    } catch (_) {
      return null;
    }
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}
