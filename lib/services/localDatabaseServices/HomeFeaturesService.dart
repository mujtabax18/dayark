import '../db/drift_database.dart';

import '../../models/HomeFeatureModel.dart';
import '../database_service.dart';

class HomeFeatureService {
  HomeFeatureService(this._databaseService);

  final DatabaseService _databaseService;

  Future<void> _initializeDefaultPositions() async {
    final db = await _databaseService.database;
    final batch = db.batch();
    for (final feature in HomeFeatureModel.defaultFeatures) {
      batch.insert(
        'home_feature_positions',
        feature.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true, continueOnError: true);
  }

  Future<List<HomeFeatureModel>> getFeatures() async {
    await _initializeDefaultPositions();
    final db = await _databaseService.database;
    final result = await db.query(
      'home_feature_positions',
      orderBy: 'position ASC',
    );

    if (result.isEmpty) {
      return [...HomeFeatureModel.defaultFeatures];
    }

    return result
        .map((map) {
          final id = map['id'] as int;
          final position = map['position'] as int;
          final feature = HomeFeatureModel.defaultFeaturesById[id];
          if (feature == null) return null;
          return feature.copyWith(position: position);
        })
        .whereType<HomeFeatureModel>()
        .toList(growable: false);
  }

  Future<void> updateFeaturePositions(List<HomeFeatureModel> features) async {
    final db = await _databaseService.database;
    final batch = db.batch();

    for (final feature in features) {
      batch.insert(
        'home_feature_positions',
        feature.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  static const String combinedCalendarVisibilityKey =
      'home_combined_calendar_visible';

  Future<bool> isCombinedCalendarVisible({int userId = 0}) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'user_settings',
      columns: ['value'],
      where: 'key = ? AND user_id = ?',
      whereArgs: [combinedCalendarVisibilityKey, userId],
      limit: 1,
    );

    // Visible by default. Only an explicit false/0 value hides it.
    if (rows.isEmpty) return true;
    final raw = (rows.first['value'] as String?)?.trim().toLowerCase();
    return raw != 'false' && raw != '0' && raw != 'hidden';
  }

  Future<void> setCombinedCalendarVisible(
    bool visible, {
    int userId = 0,
  }) async {
    final db = await _databaseService.database;
    await db.insert(
      'user_settings',
      {
        'key': combinedCalendarVisibilityKey,
        'value': visible ? 'true' : 'false',
        'user_id': userId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

}
