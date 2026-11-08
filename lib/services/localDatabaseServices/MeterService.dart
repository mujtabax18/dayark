import '../db/drift_database.dart';

import '../../models/meter.dart';
import '../database_service.dart';

class MeterBaselineAnchor {
  final int meterId;
  final int? readingId;
  final double value;
  final DateTime date;
  final DateTime updatedAt;

  const MeterBaselineAnchor({
    required this.meterId,
    required this.value,
    required this.date,
    required this.updatedAt,
    this.readingId,
  });

  factory MeterBaselineAnchor.fromJson(Map<String, dynamic> json) {
    return MeterBaselineAnchor(
      meterId: (json['meter_id'] as num).toInt(),
      readingId: (json['reading_id'] as num?)?.toInt(),
      value: (json['value'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class MeterService {
  final DatabaseService _databaseService;

  MeterService(this._databaseService);

  Future<int> addMeter(Meter meter) async {
    final db = await _databaseService.database;
    final data = Map<String, dynamic>.from(meter.toJson())..remove('id');
    final id = await db.transaction<int>((txn) async {
      final insertedId = await txn.insert('meters', data);
      if (meter.baseline != null) {
        final now = DateTime.now();
        await _upsertBaselineAnchor(
          txn,
          meterId: insertedId,
          value: meter.baseline!,
          date: now,
          updatedAt: now,
        );
      }
      return insertedId;
    });
    await _refreshMeters();
    return id;
  }

  Future<List<Meter>> getAllMeters({bool includeInactive = true}) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'meters',
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'is_active DESC, name COLLATE NOCASE ASC',
    );
    return result.map(Meter.fromJson).toList();
  }

  Future<Meter?> getMeterById(int meterId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'meters',
      where: 'id = ?',
      whereArgs: [meterId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Meter.fromJson(result.first);
  }

  Future<int> updateMeter(Meter meter) async {
    if (meter.id == null) {
      throw ArgumentError('A meter ID is required when updating a meter.');
    }

    final db = await _databaseService.database;
    final oldRows = await db.query(
      'meters',
      columns: const ['baseline'],
      where: 'id = ?',
      whereArgs: [meter.id],
      limit: 1,
    );
    final oldBaseline = oldRows.isEmpty
        ? null
        : (oldRows.first['baseline'] as num?)?.toDouble();
    final newBaseline = meter.baseline;
    final baselineChanged = !_sameNumber(oldBaseline, newBaseline);

    final data = Map<String, dynamic>.from(
      meter.copyWith(updatedAt: DateTime.now()).toJson(),
    )..remove('id');

    final result = await db.transaction<int>((txn) async {
      final updated = await txn.update(
        'meters',
        data,
        where: 'id = ?',
        whereArgs: [meter.id],
      );

      if (baselineChanged) {
        if (newBaseline == null) {
          await txn.delete(
            'meter_baseline_anchors',
            where: 'meter_id = ?',
            whereArgs: [meter.id],
          );
        } else {
          final match = await _findMatchingReading(
            txn,
            meterId: meter.id!,
            value: newBaseline,
          );
          final now = DateTime.now();
          await _upsertBaselineAnchor(
            txn,
            meterId: meter.id!,
            readingId: (match?['id'] as num?)?.toInt(),
            value: newBaseline,
            date: match == null
                ? now
                : DateTime.parse(match['date'] as String),
            updatedAt: now,
          );
        }
      }

      await _invalidateEstimatedCosts(txn, meter.id!);
      return updated;
    });

    await _refreshMeters();
    await _refreshReadings(meter.id!);
    return result;
  }

  Future<int> deleteMeter(int? id) async {
    if (id == null) return 0;
    final db = await _databaseService.database;
    final result = await db.delete('meters', where: 'id = ?', whereArgs: [id]);
    await _refreshMeters();
    return result;
  }

  Future<int> addReading(Reading reading) async {
    final db = await _databaseService.database;
    final data = Map<String, dynamic>.from(reading.toJson())..remove('id');
    final id = await db.transaction<int>((txn) async {
      final insertedId = await txn.insert('readings', data);

      // Link a manually created baseline anchor to the actual reading once the
      // matching reading is inserted.
      await txn.rawUpdate(
        'UPDATE meter_baseline_anchors '
        'SET reading_id = ?, updated_at = ? '
        'WHERE meter_id = ? AND reading_id IS NULL '
        'AND ABS(value - ?) <= 0.000001 AND date = ?',
        [
          insertedId,
          DateTime.now().toIso8601String(),
          reading.meterId,
          reading.value,
          reading.date.toIso8601String(),
        ],
      );

      await _invalidateEstimatedCosts(txn, reading.meterId);
      return insertedId;
    });
    await _refreshReadings(reading.meterId);
    return id;
  }

  Future<List<Reading>> getReadingsForMeter(int meterId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'readings',
      where: 'meter_id = ?',
      orderBy: 'date DESC, id DESC',
      whereArgs: [meterId],
    );
    return result.map(Reading.fromJson).toList();
  }

  Future<Map<int, List<Reading>>> getReadingsForMeters(
    Iterable<int> meterIds,
  ) async {
    final ids = meterIds.toSet().toList();
    if (ids.isEmpty) return {};

    final db = await _databaseService.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT * FROM readings '
      'WHERE meter_id IN ($placeholders) '
      'ORDER BY meter_id ASC, date DESC, id DESC',
      ids,
    );

    final grouped = <int, List<Reading>>{};
    for (final row in result) {
      final reading = Reading.fromJson(row);
      grouped.putIfAbsent(reading.meterId, () => []).add(reading);
    }
    return grouped;
  }

  Future<Reading?> getLatestReadingForMeter(int meterId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'readings',
      where: 'meter_id = ?',
      whereArgs: [meterId],
      orderBy: 'date DESC, id DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return Reading.fromJson(result.first);
  }

  Future<int> updateReading(Reading reading) async {
    if (reading.id == null) {
      throw ArgumentError('A reading ID is required when updating a reading.');
    }

    final db = await _databaseService.database;
    final data = Map<String, dynamic>.from(
      reading.copyWith(updatedAt: DateTime.now()).toJson(),
    )..remove('id');

    final result = await db.transaction<int>((txn) async {
      final updated = await txn.update(
        'readings',
        data,
        where: 'id = ?',
        whereArgs: [reading.id],
      );

      final anchorRows = await txn.query(
        'meter_baseline_anchors',
        where: 'meter_id = ? AND reading_id = ?',
        whereArgs: [reading.meterId, reading.id],
        limit: 1,
      );
      if (anchorRows.isNotEmpty) {
        final now = DateTime.now().toIso8601String();
        await txn.update(
          'meter_baseline_anchors',
          {
            'value': reading.value,
            'date': reading.date.toIso8601String(),
            'updated_at': now,
          },
          where: 'meter_id = ?',
          whereArgs: [reading.meterId],
        );
        await txn.update(
          'meters',
          {
            'baseline': reading.value,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [reading.meterId],
        );
      }

      await _invalidateEstimatedCosts(txn, reading.meterId);
      return updated;
    });

    await _refreshMeters();
    await _refreshReadings(reading.meterId);
    return result;
  }

  Future<int> deleteReading(int? id, int meterId) async {
    if (id == null) return 0;
    final db = await _databaseService.database;
    final result = await db.transaction<int>((txn) async {
      await txn.update(
        'meter_baseline_anchors',
        {
          'reading_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'meter_id = ? AND reading_id = ?',
        whereArgs: [meterId, id],
      );
      final deleted = await txn.delete(
        'readings',
        where: 'id = ?',
        whereArgs: [id],
      );
      await _invalidateEstimatedCosts(txn, meterId);
      return deleted;
    });
    await _refreshReadings(meterId);
    return result;
  }

  Future<void> updateMeterBaseline(
    int meterId,
    num baseline, {
    DateTime? baselineDate,
    int? readingId,
  }) async {
    final db = await _databaseService.database;
    final now = DateTime.now();

    await db.transaction((txn) async {
      Map<String, Object?>? match;
      if (readingId == null || baselineDate == null) {
        match = await _findMatchingReading(
          txn,
          meterId: meterId,
          value: baseline.toDouble(),
          preferredReadingId: readingId,
        );
      }

      final resolvedReadingId = readingId ?? (match?['id'] as num?)?.toInt();
      final resolvedDate = baselineDate ??
          (match == null
              ? now
              : DateTime.parse(match['date'] as String));

      await txn.update(
        'meters',
        {
          'baseline': baseline.toDouble(),
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [meterId],
      );

      await _upsertBaselineAnchor(
        txn,
        meterId: meterId,
        readingId: resolvedReadingId,
        value: baseline.toDouble(),
        date: resolvedDate,
        updatedAt: now,
      );

      await _invalidateEstimatedCosts(txn, meterId);
    });

    await _refreshMeters();
    await _refreshReadings(meterId);
  }

  Future<MeterBaselineAnchor?> getBaselineAnchor(int meterId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'meter_baseline_anchors',
      where: 'meter_id = ?',
      whereArgs: [meterId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return MeterBaselineAnchor.fromJson(result.first);
  }

  Future<Map<int, MeterBaselineAnchor>> getBaselineAnchorsForMeters(
    Iterable<int> meterIds,
  ) async {
    final ids = meterIds.toSet().toList();
    if (ids.isEmpty) return {};

    final db = await _databaseService.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT * FROM meter_baseline_anchors '
      'WHERE meter_id IN ($placeholders)',
      ids,
    );

    return {
      for (final row in result)
        (row['meter_id'] as num).toInt(): MeterBaselineAnchor.fromJson(row),
    };
  }

  /// Kept for compatibility with older screens.
  Future<void> updateMeterNumber(int? meterId, String? number) async {
    if (meterId == null) return;
    final db = await _databaseService.database;
    await db.update(
      'meters',
      {
        'number': number ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [meterId],
    );
    await _refreshMeters();
  }

  Future<List<MeterTariffSlab>> getTariffSlabs(int meterId) async {
    final db = await _databaseService.database;
    final result = await db.query(
      'meter_tariff_slabs',
      where: 'meter_id = ?',
      whereArgs: [meterId],
      orderBy: 'position ASC, from_unit ASC',
    );
    return result.map(MeterTariffSlab.fromJson).toList();
  }

  Future<Map<int, List<MeterTariffSlab>>> getTariffSlabsForMeters(
    Iterable<int> meterIds,
  ) async {
    final ids = meterIds.toSet().toList();
    if (ids.isEmpty) return {};

    final db = await _databaseService.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT * FROM meter_tariff_slabs '
      'WHERE meter_id IN ($placeholders) '
      'ORDER BY meter_id ASC, position ASC, from_unit ASC',
      ids,
    );

    final grouped = <int, List<MeterTariffSlab>>{};
    for (final row in result) {
      final slab = MeterTariffSlab.fromJson(row);
      grouped.putIfAbsent(slab.meterId, () => []).add(slab);
    }
    return grouped;
  }

  Future<void> replaceTariffSlabs(
    int meterId,
    List<MeterTariffSlab> slabs,
  ) async {
    final db = await _databaseService.database;
    await db.transaction((txn) async {
      await txn.delete(
        'meter_tariff_slabs',
        where: 'meter_id = ?',
        whereArgs: [meterId],
      );

      for (var index = 0; index < slabs.length; index++) {
        final data = Map<String, dynamic>.from(
          slabs[index].copyWith(
            meterId: meterId,
            position: index,
          ).toJson(),
        )..remove('id');
        await txn.insert('meter_tariff_slabs', data);
      }

      await _invalidateEstimatedCosts(txn, meterId);
    });

    await _refreshReadings(meterId);
  }

  Future<Map<String, Object?>?> _findMatchingReading(
    Transaction txn, {
    required int meterId,
    required double value,
    int? preferredReadingId,
  }) async {
    if (preferredReadingId != null) {
      final preferred = await txn.query(
        'readings',
        where: 'meter_id = ? AND id = ?',
        whereArgs: [meterId, preferredReadingId],
        limit: 1,
      );
      if (preferred.isNotEmpty) return preferred.first;
    }

    final matches = await txn.query(
      'readings',
      where: 'meter_id = ? AND ABS(value - ?) <= 0.000001',
      whereArgs: [meterId, value],
      orderBy: 'date DESC, id DESC',
      limit: 1,
    );
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> _upsertBaselineAnchor(
    Transaction txn, {
    required int meterId,
    required double value,
    required DateTime date,
    required DateTime updatedAt,
    int? readingId,
  }) async {
    await txn.insert(
      'meter_baseline_anchors',
      {
        'meter_id': meterId,
        'reading_id': readingId,
        'value': value,
        'date': date.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _invalidateEstimatedCosts(
    Transaction txn,
    int meterId,
  ) async {
    await txn.update(
      'readings',
      {'estimated_cost': null},
      where: 'meter_id = ?',
      whereArgs: [meterId],
    );
  }

  static bool _sameNumber(double? first, double? second) {
    if (first == null || second == null) return first == second;
    return (first - second).abs() <= 0.000001;
  }

  Future<void> _refreshMeters() async {
    final meters = await getAllMeters();
    if (!_databaseService.meterStreamController.isClosed) {
      _databaseService.meterStreamController.add(meters);
    }
  }

  Future<void> _refreshReadings(int meterId) async {
    final readings = await getReadingsForMeter(meterId);
    if (!_databaseService.readingStreamController.isClosed) {
      _databaseService.readingStreamController.add(readings);
    }
  }
}
