import 'dart:async';
import 'dart:convert';

import '../db/drift_database.dart';

import '../database_service.dart';

class PillReminderService {
  PillReminderService(this._databaseService);

  final DatabaseService _databaseService;
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<String> get statusStream => _statusController.stream;

  void _emit(String message) {
    if (!_statusController.isClosed) _statusController.add(message);
  }

  void dispose() => _statusController.close();

  // ---------------------------------------------------------------------------
  // Profiles
  // ---------------------------------------------------------------------------

  Future<int> createProfile(String name) async {
    final db = await _databaseService.database;
    return db.insert('profiles', {
      'name': name.trim(),
      'is_active': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateProfile(int id, Map<String, dynamic> data) async {
    final db = await _databaseService.database;
    return db.update(
      'profiles',
      {...data, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProfile(int id) async {
    final db = await _databaseService.database;
    final activeId = await getActiveProfileId();
    if (activeId == id) throw Exception('Switch profile before deleting it');
    return db.delete('profiles', where: 'id = ?', whereArgs: [id]);
  }

  Future<int?> getActiveProfileId() async {
    final db = await _databaseService.database;
    final result = await db.query(
      'profiles',
      columns: ['id'],
      where: 'is_active = 1',
      limit: 1,
    );
    return result.isEmpty ? null : result.first['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getAllProfiles() async {
    final db = await _databaseService.database;
    return db.query('profiles', orderBy: 'is_active DESC, name COLLATE NOCASE');
  }

  Future<List<Map<String, dynamic>>> getProfiles() => getAllProfiles();

  Future<void> setActiveProfile(int profileId) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update('profiles', {'is_active': 0});
      final count = await txn.update(
        'profiles',
        {'is_active': 1},
        where: 'id = ?',
        whereArgs: [profileId],
      );
      if (count == 0) throw Exception('Profile not found');
    });
  }

  // ---------------------------------------------------------------------------
  // Medicine and dosage types
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getPillTypes() async {
    final db = await _databaseService.database;
    return db.query('pill_types', orderBy: 'is_system DESC, id ASC');
  }

  Future<int> createPillType(String name) async {
    final db = await _databaseService.database;
    return db.insert('pill_types', {'name': name.trim(), 'is_system': 0});
  }

  Future<int> updatePillType(int id, String name) async {
    final db = await _databaseService.database;
    await _ensureTypeIsEditable(db, 'pill_types', id);
    return db.update(
      'pill_types',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePillType(int id) async {
    final db = await _databaseService.database;
    await _ensureTypeIsEditable(db, 'pill_types', id);
    return db.delete('pill_types', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDosageTypes() async {
    final db = await _databaseService.database;
    return db.query('dosage_types', orderBy: 'is_system DESC, id ASC');
  }

  Future<int> createDosageType(String name) async {
    final db = await _databaseService.database;
    return db.insert('dosage_types', {'name': name.trim(), 'is_system': 0});
  }

  Future<int> updateDosageType(int id, String name) async {
    final db = await _databaseService.database;
    await _ensureTypeIsEditable(db, 'dosage_types', id);
    return db.update(
      'dosage_types',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDosageType(int id) async {
    final db = await _databaseService.database;
    await _ensureTypeIsEditable(db, 'dosage_types', id);
    return db.delete('dosage_types', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _ensureTypeIsEditable(
    DatabaseExecutor db,
    String table,
    int id,
  ) async {
    final rows = await db.query(
      table,
      columns: ['is_system'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw Exception('Type not found');
    if ((rows.first['is_system'] as num?)?.toInt() == 1) {
      throw Exception('Default types cannot be changed');
    }
  }

  // ---------------------------------------------------------------------------
  // Create / edit medicine
  // ---------------------------------------------------------------------------

  Future<void> createFullPill({
    required String name,
    required double dosageValue,
    required int dosageTypeId,
    required int pillTypeId,
    required String notes,
    required String startDate,
    String? endDate,
    required double initialQuantity,
    double doseQuantity = 1,
    String colorHex = '#6C63FF',
    bool trackInventory = true,
    int lowInventoryAlertAt = 5,
    required String ruleType,
    required List<String> times,
    List<int>? daysOfWeek,
    List<int>? daysOfMonth,
    int? intervalDays,
  }) async {
    _validateSchedule(
      ruleType: ruleType,
      times: times,
      daysOfWeek: daysOfWeek,
      daysOfMonth: daysOfMonth,
      intervalDays: intervalDays,
    );
    if (doseQuantity <= 0) throw Exception('Dose quantity must be above zero');

    final db = await _databaseService.database;
    final profileId = await getActiveProfileId();
    if (profileId == null) throw Exception('No active profile');

    await db.transaction((txn) async {
      _emit('Saving medicine');
      final now = DateTime.now().toIso8601String();
      final pillId = await txn.insert('pills', {
        'profile_id': profileId,
        'name': name.trim(),
        'dosage_value': dosageValue,
        'dose_quantity': doseQuantity,
        'dosage_type_id': dosageTypeId,
        'pill_type_id': pillTypeId,
        'color_hex': colorHex,
        'track_inventory': trackInventory ? 1 : 0,
        'notes': notes.trim(),
        'start_date': startDate,
        'end_date': _nullableDate(endDate),
        'is_active': 1,
        'created_at': now,
      });

      await txn.insert('pill_inventory', {
        'pill_id': pillId,
        'total_quantity': trackInventory ? initialQuantity : 0,
        'remaining_quantity': trackInventory ? initialQuantity : 0,
        'low_stock_threshold': lowInventoryAlertAt,
        'last_updated': now,
      });

      final ruleId = await txn.insert('schedule_rules', {
        'pill_id': pillId,
        'rule_type': ruleType,
        'times': jsonEncode(_sortedTimes(times)),
        'days_of_week': _encodeNullable(daysOfWeek),
        'days_of_month': _encodeNullable(daysOfMonth),
        'interval_days': intervalDays,
        'start_date': startDate,
        'end_date': _nullableDate(endDate),
        'is_active': 1,
        'created_at': now,
      });

      final generationStart = DateTime.parse(startDate);
      await txn.insert('occurrence_generation_tracker', {
        'pill_id': pillId,
        'schedule_rule_id': ruleId,
        'generated_until_date': _dateKey(
          generationStart.subtract(const Duration(days: 1)),
        ),
        'last_generated_at': now,
      });

      await _generateOccurrences(
        txn: txn,
        pillId: pillId,
        ruleId: ruleId,
        fromDate: generationStart,
        throughDate: DateTime.now().add(const Duration(days: 60)),
      );
      _emit('Medicine saved');
    });
  }

  Future<void> editPill({
    required int pillId,
    required String name,
    required double dosageValue,
    required int dosageTypeId,
    required int pillTypeId,
    required String notes,
    required String startDate,
    String? endDate,
    double doseQuantity = 1,
    String colorHex = '#6C63FF',
    bool trackInventory = true,
    int lowInventoryAlertAt = 5,
    required String ruleType,
    required List<String> times,
    List<int>? daysOfWeek,
    List<int>? daysOfMonth,
    int? intervalDays,
  }) async {
    _validateSchedule(
      ruleType: ruleType,
      times: times,
      daysOfWeek: daysOfWeek,
      daysOfMonth: daysOfMonth,
      intervalDays: intervalDays,
    );

    final db = await _databaseService.database;
    await db.transaction((txn) async {
      final now = DateTime.now();
      final todayKey = _dateKey(now);
      final start = DateTime.parse(startDate);

      await txn.update(
        'pills',
        {
          'name': name.trim(),
          'dosage_value': dosageValue,
          'dose_quantity': doseQuantity,
          'dosage_type_id': dosageTypeId,
          'pill_type_id': pillTypeId,
          'color_hex': colorHex,
          'track_inventory': trackInventory ? 1 : 0,
          'notes': notes.trim(),
          'start_date': startDate,
          'end_date': _nullableDate(endDate),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [pillId],
      );

      await txn.update(
        'pill_inventory',
        {
          'low_stock_threshold': lowInventoryAlertAt,
          'last_updated': now.toIso8601String(),
        },
        where: 'pill_id = ?',
        whereArgs: [pillId],
      );

      final rules = await txn.query(
        'schedule_rules',
        where: 'pill_id = ? AND is_active = 1',
        whereArgs: [pillId],
        limit: 1,
      );
      if (rules.isEmpty) throw Exception('Active schedule not found');
      final ruleId = rules.first['id'] as int;

      await txn.update(
        'schedule_rules',
        {
          'rule_type': ruleType,
          'times': jsonEncode(_sortedTimes(times)),
          'days_of_week': _encodeNullable(daysOfWeek),
          'days_of_month': _encodeNullable(daysOfMonth),
          'interval_days': intervalDays,
          'start_date': startDate,
          'end_date': _nullableDate(endDate),
        },
        where: 'id = ?',
        whereArgs: [ruleId],
      );

      await txn.delete(
        'reminder_occurrences',
        where: 'pill_id = ? AND scheduled_date >= ?',
        whereArgs: [pillId, todayKey],
      );

      final generationStart = start.isAfter(_dateOnly(now)) ? start : _dateOnly(now);
      await txn.update(
        'occurrence_generation_tracker',
        {
          'generated_until_date': _dateKey(
            generationStart.subtract(const Duration(days: 1)),
          ),
          'last_generated_at': now.toIso8601String(),
        },
        where: 'pill_id = ? AND schedule_rule_id = ?',
        whereArgs: [pillId, ruleId],
      );

      await _generateOccurrences(
        txn: txn,
        pillId: pillId,
        ruleId: ruleId,
        fromDate: generationStart,
        throughDate: now.add(const Duration(days: 60)),
      );
    });
  }

  void _validateSchedule({
    required String ruleType,
    required List<String> times,
    List<int>? daysOfWeek,
    List<int>? daysOfMonth,
    int? intervalDays,
  }) {
    const allowed = {'ONCE', 'DAILY', 'WEEKLY', 'MONTHLY', 'INTERVAL'};
    if (!allowed.contains(ruleType)) throw Exception('Invalid repeat option');
    if (times.isEmpty) throw Exception('Add at least one reminder time');
    if (ruleType == 'WEEKLY' && (daysOfWeek == null || daysOfWeek.isEmpty)) {
      throw Exception('Select at least one weekday');
    }
    if (ruleType == 'MONTHLY' &&
        (daysOfMonth == null || daysOfMonth.isEmpty)) {
      throw Exception('Select a day of month');
    }
    if (ruleType == 'INTERVAL' && (intervalDays == null || intervalDays < 1)) {
      throw Exception('Custom interval must be at least one day');
    }
  }

  // ---------------------------------------------------------------------------
  // Activation and occurrence generation
  // ---------------------------------------------------------------------------

  Future<void> deletePill(int pillId) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update(
        'pills',
        {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [pillId],
      );
      await txn.update(
        'schedule_rules',
        {'is_active': 0},
        where: 'pill_id = ?',
        whereArgs: [pillId],
      );
      await txn.delete(
        'reminder_occurrences',
        where: 'pill_id = ? AND scheduled_date >= ?',
        whereArgs: [pillId, _dateKey(DateTime.now())],
      );
    });
  }

  /// Permanently removes a medicine and every local record linked to it.
  ///
  /// This is intentionally separate from [deletePill], which only marks a
  /// medicine inactive and can be undone. Child rows are deleted explicitly so
  /// this remains safe for databases created before foreign-key cascades were
  /// enabled.
  Future<void> permanentlyDeletePill(int pillId) async {
    final db = await _databaseService.database;

    await db.transaction((txn) async {
      final pill = await txn.query(
        'pills',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [pillId],
        limit: 1,
      );
      if (pill.isEmpty) throw Exception('Medicine not found');

      _emit('Deleting medicine');

      // Delete in dependency order. This includes pending reminders and the
      // complete Taken / Missed / Skipped history stored as occurrences.
      await txn.delete(
        'reminder_occurrences',
        where: 'pill_id = ?',
        whereArgs: [pillId],
      );
      await txn.delete(
        'occurrence_generation_tracker',
        where: 'pill_id = ?',
        whereArgs: [pillId],
      );
      await txn.delete(
        'schedule_rules',
        where: 'pill_id = ?',
        whereArgs: [pillId],
      );
      await txn.delete(
        'pill_inventory',
        where: 'pill_id = ?',
        whereArgs: [pillId],
      );

      final deleted = await txn.delete(
        'pills',
        where: 'id = ?',
        whereArgs: [pillId],
      );
      if (deleted == 0) throw Exception('Medicine could not be deleted');

      _emit('Medicine deleted');
    });
  }

  Future<void> undoDeletePill(int pillId) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.update(
        'pills',
        {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [pillId],
      );
      await txn.update(
        'schedule_rules',
        {'is_active': 1},
        where: 'pill_id = ?',
        whereArgs: [pillId],
      );

      final rules = await txn.query(
        'schedule_rules',
        where: 'pill_id = ? AND is_active = 1',
        whereArgs: [pillId],
        limit: 1,
      );
      if (rules.isEmpty) return;
      final ruleId = rules.first['id'] as int;
      final start = DateTime.parse(rules.first['start_date'] as String);
      final today = _dateOnly(DateTime.now());
      final from = start.isAfter(today) ? start : today;

      await txn.update(
        'occurrence_generation_tracker',
        {
          'generated_until_date': _dateKey(from.subtract(const Duration(days: 1))),
          'last_generated_at': DateTime.now().toIso8601String(),
        },
        where: 'pill_id = ? AND schedule_rule_id = ?',
        whereArgs: [pillId, ruleId],
      );

      await _generateOccurrences(
        txn: txn,
        pillId: pillId,
        ruleId: ruleId,
        fromDate: from,
        throughDate: today.add(const Duration(days: 60)),
      );
    });
  }

  Future<void> runDailyOccurrenceGeneration() async {
    await ensureOccurrencesGenerated(
      throughDate: DateTime.now().add(const Duration(days: 60)),
    );
    await refreshMissedOccurrences();
  }

  Future<void> ensureOccurrencesGenerated({DateTime? throughDate}) async {
    final db = await _databaseService.database;
    final target = _dateOnly(
      throughDate ?? DateTime.now().add(const Duration(days: 60)),
    );
    final rows = await db.rawQuery('''
      SELECT
        t.pill_id,
        t.schedule_rule_id,
        t.generated_until_date,
        r.start_date
      FROM occurrence_generation_tracker t
      JOIN schedule_rules r ON r.id = t.schedule_rule_id
      JOIN pills p ON p.id = t.pill_id
      WHERE r.is_active = 1 AND p.is_active = 1
    ''');

    for (final row in rows) {
      final generatedUntil = DateTime.parse(row['generated_until_date'] as String);
      if (!generatedUntil.isBefore(target)) continue;
      final ruleStart = DateTime.parse(row['start_date'] as String);
      final next = generatedUntil.add(const Duration(days: 1));
      final from = next.isBefore(ruleStart) ? ruleStart : next;
      await _generateOccurrences(
        txn: db,
        pillId: row['pill_id'] as int,
        ruleId: row['schedule_rule_id'] as int,
        fromDate: from,
        throughDate: target,
      );
    }
  }

  Future<void> _generateOccurrences({
    required DatabaseExecutor txn,
    required int pillId,
    required int ruleId,
    required DateTime fromDate,
    required DateTime throughDate,
    Map<String, dynamic>? ruleRow,
  }) async {
    ruleRow ??= (await txn.query(
      'schedule_rules',
      where: 'id = ?',
      whereArgs: [ruleId],
      limit: 1,
    ))
        .first;

    final ruleType = ruleRow['rule_type'] as String;
    final times = List<String>.from(jsonDecode(ruleRow['times'] as String));
    final weekdays = _decodeIntList(ruleRow['days_of_week']);
    final monthDays = _decodeIntList(ruleRow['days_of_month']);
    final intervalDays = (ruleRow['interval_days'] as num?)?.toInt() ?? 1;
    final ruleStart = _dateOnly(DateTime.parse(ruleRow['start_date'] as String));
    final configuredEnd = ruleRow['end_date'] == null
        ? null
        : _dateOnly(DateTime.parse(ruleRow['end_date'] as String));

    var current = _dateOnly(fromDate);
    if (current.isBefore(ruleStart)) current = ruleStart;
    var end = _dateOnly(throughDate);
    if (configuredEnd != null && configuredEnd.isBefore(end)) end = configuredEnd;

    if (current.isAfter(end)) {
      await _updateTracker(txn, pillId, ruleId, end);
      return;
    }

    while (!current.isAfter(end)) {
      final difference = current.difference(ruleStart).inDays;
      final shouldCreate = switch (ruleType) {
        'ONCE' => difference == 0,
        'DAILY' => true,
        'WEEKLY' => weekdays.contains(current.weekday),
        'MONTHLY' => monthDays.contains(current.day),
        'INTERVAL' => difference >= 0 && difference % intervalDays == 0,
        _ => false,
      };

      if (shouldCreate) {
        for (final time in times) {
          await txn.insert(
            'reminder_occurrences',
            {
              'pill_id': pillId,
              'schedule_rule_id': ruleId,
              'scheduled_date': _dateKey(current),
              'scheduled_time': time,
              'status': _initialStatus(current, time),
              'created_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      current = current.add(const Duration(days: 1));
    }

    await _updateTracker(txn, pillId, ruleId, end);
  }

  Future<void> _updateTracker(
    DatabaseExecutor txn,
    int pillId,
    int ruleId,
    DateTime generatedUntil,
  ) async {
    await txn.update(
      'occurrence_generation_tracker',
      {
        'generated_until_date': _dateKey(generatedUntil),
        'last_generated_at': DateTime.now().toIso8601String(),
      },
      where: 'pill_id = ? AND schedule_rule_id = ?',
      whereArgs: [pillId, ruleId],
    );
  }

  String _initialStatus(DateTime date, String time) {
    final scheduled = _scheduledDateTime(_dateKey(date), time);
    return scheduled.isBefore(DateTime.now()) ? 'MISSED' : 'PENDING';
  }

  Future<void> refreshMissedOccurrences() async {
    final db = await _databaseService.database;
    final now = DateTime.now();
    await db.update(
      'reminder_occurrences',
      {'status': 'MISSED'},
      where: '''
        status = 'PENDING'
        AND (
          scheduled_date < ? OR
          (scheduled_date = ? AND scheduled_time < ?)
        )
      ''',
      whereArgs: [_dateKey(now), _dateKey(now), _timeKey(now)],
    );
  }

  // ---------------------------------------------------------------------------
  // Occurrence actions and inventory
  // ---------------------------------------------------------------------------

  Future<void> markOccurrence({
    required int occurrenceId,
    required String status,
  }) async {
    const statuses = {'PENDING', 'TAKEN', 'SKIPPED', 'MISSED'};
    if (!statuses.contains(status)) throw Exception('Invalid status');

    final db = await _databaseService.database;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT
          ro.*,
          p.dose_quantity,
          p.track_inventory
        FROM reminder_occurrences ro
        JOIN pills p ON p.id = ro.pill_id
        WHERE ro.id = ?
        LIMIT 1
      ''', [occurrenceId]);
      if (rows.isEmpty) throw Exception('Reminder not found');

      final occurrence = rows.first;
      final scheduled = _scheduledDateTime(
        occurrence['scheduled_date'] as String,
        occurrence['scheduled_time'] as String,
      );
      if (scheduled.isAfter(DateTime.now())) {
        throw Exception('A future dose cannot be completed yet');
      }

      final previous = occurrence['status'] as String;
      if (previous == status) return;

      final tracksInventory = (occurrence['track_inventory'] as num?)?.toInt() == 1;
      final dose = (occurrence['dose_quantity'] as num?)?.toDouble() ?? 1;
      if (tracksInventory && previous == 'TAKEN' && status != 'TAKEN') {
        await _adjustInventory(txn, occurrence['pill_id'] as int, dose);
      }
      if (tracksInventory && previous != 'TAKEN' && status == 'TAKEN') {
        await _adjustInventory(txn, occurrence['pill_id'] as int, -dose);
      }

      await txn.update(
        'reminder_occurrences',
        {
          'status': status,
          'action_time': status == 'PENDING' ? null : DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [occurrenceId],
      );
    });
  }

  Future<void> _adjustInventory(
    DatabaseExecutor txn,
    int pillId,
    double delta,
  ) async {
    final rows = await txn.query(
      'pill_inventory',
      where: 'pill_id = ?',
      whereArgs: [pillId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final current = (rows.first['remaining_quantity'] as num).toDouble();
    final updated = current + delta;
    if (updated < 0) throw Exception('Not enough stock for this dose');
    await txn.update(
      'pill_inventory',
      {
        'remaining_quantity': updated,
        'last_updated': DateTime.now().toIso8601String(),
      },
      where: 'pill_id = ?',
      whereArgs: [pillId],
    );
  }

  Future<void> refillInventory({
    required int pillId,
    required double addQuantity,
  }) async {
    if (addQuantity <= 0) throw Exception('Refill quantity must be above zero');
    final db = await _databaseService.database;
    await db.rawUpdate('''
      UPDATE pill_inventory
      SET total_quantity = total_quantity + ?,
          remaining_quantity = remaining_quantity + ?,
          last_updated = ?
      WHERE pill_id = ?
    ''', [addQuantity, addQuantity, DateTime.now().toIso8601String(), pillId]);
  }

  // ---------------------------------------------------------------------------
  // Queries used by dashboard, calendar and medicine list
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getOccurrencesForDate(String date) {
    return getOccurrencesForRange(date, date);
  }

  Future<List<Map<String, dynamic>>> getOccurrencesForRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _databaseService.database;
    final profileId = await getActiveProfileId();
    if (profileId == null) return [];

    return db.rawQuery('''
      SELECT
        ro.id,
        ro.pill_id,
        ro.scheduled_date,
        ro.scheduled_time,
        ro.status,
        ro.action_time,
        p.name AS pill_name,
        p.dosage_value,
        p.dose_quantity,
        p.color_hex,
        p.track_inventory,
        p.notes,
        pt.name AS pill_type_name,
        dt.name AS dosage_type_name,
        i.remaining_quantity,
        i.low_stock_threshold
      FROM reminder_occurrences ro
      JOIN pills p ON p.id = ro.pill_id
      LEFT JOIN pill_types pt ON pt.id = p.pill_type_id
      LEFT JOIN dosage_types dt ON dt.id = p.dosage_type_id
      LEFT JOIN pill_inventory i ON i.pill_id = p.id
      WHERE ro.scheduled_date BETWEEN ? AND ?
        AND p.profile_id = ?
        AND p.is_active = 1
      ORDER BY ro.scheduled_date ASC, ro.scheduled_time ASC, p.name COLLATE NOCASE
    ''', [startDate, endDate, profileId]);
  }

  Future<List<Map<String, dynamic>>> getLowStockPills() async {
    final db = await _databaseService.database;
    final profileId = await getActiveProfileId();
    if (profileId == null) return [];
    return db.rawQuery('''
      SELECT
        p.*,
        pt.name AS pill_type_name,
        dt.name AS dosage_type_name,
        i.total_quantity,
        i.remaining_quantity,
        i.low_stock_threshold
      FROM pills p
      JOIN pill_inventory i ON i.pill_id = p.id
      LEFT JOIN pill_types pt ON pt.id = p.pill_type_id
      LEFT JOIN dosage_types dt ON dt.id = p.dosage_type_id
      WHERE p.profile_id = ?
        AND p.is_active = 1
        AND p.track_inventory = 1
        AND i.remaining_quantity <= i.low_stock_threshold
      ORDER BY i.remaining_quantity ASC, p.name COLLATE NOCASE
    ''', [profileId]);
  }

  Future<List<Map<String, dynamic>>> getPillsWithInventory() async {
    final rows = await getPillsWithInventoryAll();
    return rows.where((row) => row['is_active'] == 1).toList();
  }

  Future<List<Map<String, dynamic>>> getPillsWithInventoryAll() async {
    final db = await _databaseService.database;
    final profileId = await getActiveProfileId();
    if (profileId == null) return [];

    return db.rawQuery('''
      SELECT
        p.*,
        pt.name AS pill_type_name,
        dt.name AS dosage_type_name,
        i.total_quantity,
        i.remaining_quantity,
        i.low_stock_threshold,
        sr.rule_type,
        sr.times,
        sr.days_of_week,
        sr.days_of_month,
        sr.interval_days
      FROM pills p
      LEFT JOIN pill_types pt ON pt.id = p.pill_type_id
      LEFT JOIN dosage_types dt ON dt.id = p.dosage_type_id
      LEFT JOIN pill_inventory i ON i.pill_id = p.id
      LEFT JOIN schedule_rules sr
        ON sr.pill_id = p.id AND sr.is_active = 1
      WHERE p.profile_id = ?
      ORDER BY p.is_active DESC, p.name COLLATE NOCASE
    ''', [profileId]);
  }

  Future<Map<String, dynamic>?> getActiveScheduleRule(int pillId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'schedule_rules',
      where: 'pill_id = ? AND is_active = 1',
      whereArgs: [pillId],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  Future<Map<String, dynamic>?> getPillInventory(int pillId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'pill_inventory',
      where: 'pill_id = ?',
      whereArgs: [pillId],
      limit: 1,
    );
    return result.isEmpty ? null : result.first;
  }

  Future<Map<String, int>> getStatsUntilDate(String date) async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return _emptyStats();
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT ro.status, COUNT(*) AS count
      FROM reminder_occurrences ro
      JOIN pills p ON p.id = ro.pill_id
      WHERE ro.scheduled_date <= ? AND p.profile_id = ?
      GROUP BY ro.status
    ''', [date, profileId]);
    return _statsFromRows(rows);
  }

  Future<Map<String, int>> getStatsForExactDate(String date) async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return _emptyStats();
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT ro.status, COUNT(*) AS count
      FROM reminder_occurrences ro
      JOIN pills p ON p.id = ro.pill_id
      WHERE ro.scheduled_date = ? AND p.profile_id = ?
      GROUP BY ro.status
    ''', [date, profileId]);
    return _statsFromRows(rows);
  }

  Map<String, int> _statsFromRows(List<Map<String, Object?>> rows) {
    final stats = _emptyStats();
    for (final row in rows) {
      stats[row['status'] as String] = (row['count'] as num).toInt();
    }
    return stats;
  }

  Map<String, int> _emptyStats() => {
        'PENDING': 0,
        'TAKEN': 0,
        'MISSED': 0,
        'SKIPPED': 0,
      };

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String? _nullableDate(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  String? _encodeNullable(List<int>? values) {
    if (values == null || values.isEmpty) return null;
    final sorted = [...values]..sort();
    return jsonEncode(sorted);
  }

  List<int> _decodeIntList(dynamic value) {
    if (value == null) return const [];
    try {
      return List<int>.from(jsonDecode(value.toString()));
    } catch (_) {
      return const [];
    }
  }

  List<String> _sortedTimes(List<String> times) {
    final unique = times.toSet().toList()..sort();
    return unique;
  }

  DateTime _scheduledDateTime(String date, String time) {
    final dateParts = date.split('-').map(int.parse).toList();
    final timeParts = time.split(':').map(int.parse).toList();
    return DateTime(
      dateParts[0],
      dateParts[1],
      dateParts[2],
      timeParts[0],
      timeParts[1],
    );
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _timeKey(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
