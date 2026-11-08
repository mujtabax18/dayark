import '../db/drift_database.dart';
import 'package:path/path.dart';

import '../../models/NotificationSettings.dart';
import '../../models/moodTrackerModel.dart';
import '../database_service.dart';

class NotificationSettingService {
  final DatabaseService _databaseService;

  NotificationSettingService(this._databaseService);

  // Add these methods to your DatabaseService
  Future<int> insertNotificationSettings(NotificationSettings settings) async {
    final db = await _databaseService.database;
    return await db.insert('notification_settings', settings.toMap());
  }

  Future<int> updateNotificationSettings(NotificationSettings settings) async {
    final db = await _databaseService.database;
    return await db.update(
      'notification_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [settings.id],
    );
  }

  Future<NotificationSettings?> getNotificationSettings(
      String featureName) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notification_settings',
      where: 'feature_name = ?',
      whereArgs: [featureName],
      limit: 1,
    );
    return maps.isNotEmpty ? NotificationSettings.fromMap(maps.first) : null;
  }

  Future<List<NotificationSettings>> getAllNotificationSettings() async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps =
        await db.query('notification_settings');
    return maps.map((map) => NotificationSettings.fromMap(map)).toList();
  }

  Future<NotificationSettings> getSettingsOrDefault(String featureName) async {
    final settings = await getNotificationSettings(featureName);
    return settings ??
        NotificationSettings(
          featureName: featureName,
          isActive: false,
          intervalType: 'days',
          intervalValue: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
  }

  Future<List<NotificationSettings>> getActiveNotificationSettings() async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notification_settings',
      where: 'is_active = 1',
    );
    return maps.map((map) => NotificationSettings.fromMap(map)).toList();
  }

  Future<int> saveSettings(NotificationSettings settings) async {
    final db = await _databaseService.database;
    if (settings.id == null) {
      return await db.insert(
        'notification_settings',
        settings
            .copyWith(
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
            .toMap(),
      );
    } else {
      return await db.update(
        'notification_settings',
        settings.copyWith(updatedAt: DateTime.now()).toMap(),
        where: 'id = ?',
        whereArgs: [settings.id],
      );
    }
  }
}
