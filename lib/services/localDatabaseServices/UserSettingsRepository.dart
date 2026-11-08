import '../db/drift_database.dart';

import '../../utlis/app_setting_X.dart';
import '../../utlis/enums.dart';
import '../database_service.dart';

class UserSettingsRepository {
  final DatabaseService dbService;

  UserSettingsRepository(this.dbService);

  Future<String?> getValue(
    AppSettingKey kkey, {
    int userId = 0,
  }) async {
    final db = await dbService.database;
    final result = await db.query(
      'user_settings',
      where: 'key = ? AND user_id = ?',
      whereArgs: [kkey.key, userId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return result.first['value'] as String;
  }

  Future<void> setValue(
    AppSettingKey kkey,
    String value, {
    int userId = 0,
  }) async {
    final db = await dbService.database;
    await db.insert(
      'user_settings',
      {
        'key': kkey.key,
        'value': value,
        'user_id': userId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceLegacyDollarCurrency(String currencySymbol) async {
    final cleanSymbol = currencySymbol.trim();
    if (cleanSymbol.isEmpty || cleanSymbol == r'$') return;

    final db = await dbService.database;
    for (final table in ['invoices', 'invoice_business_profiles']) {
      final exists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
        [table],
      );
      if (exists.isEmpty) continue;
      await db.update(
        table,
        {'currencySymbol': cleanSymbol},
        where: 'currencySymbol = ?',
        whereArgs: [r'$'],
      );
    }
  }

}
