import '../db/drift_database.dart';

import '../database_service.dart';

class NotificationLogService {
  final DatabaseService _databaseService;

  NotificationLogService(this._databaseService);

  Future<DateTime?> getLastSentTime(int settingId) async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notification_logs',
      where: 'setting_id = ?',
      whereArgs: [settingId],
      orderBy: 'last_sent DESC',
      limit: 1,
    );

    return maps.isNotEmpty ? DateTime.parse(maps.first['last_sent']) : null;
  }

  Future<void> recordNotificationSent(int settingId) async {
    final db = await _databaseService.database;
    await db.insert('notification_logs', {
      'setting_id': settingId,
      'last_sent': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> clearLogsForSetting(int settingId) async {
    final db = await _databaseService.database;
    await db.delete(
      'notification_logs',
      where: 'setting_id = ?',
      whereArgs: [settingId],
    );
  }

  Future<int> getNotificationCount(int settingId,
      {Duration? withinDuration}) async {
    final db = await _databaseService.database;
    final where = StringBuffer('setting_id = ?');
    final whereArgs = <dynamic>[settingId];

    if (withinDuration != null) {
      where.write(' AND last_sent >= ?');
      whereArgs.add(DateTime.now().subtract(withinDuration).toIso8601String());
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notification_logs WHERE $where',
      whereArgs,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
