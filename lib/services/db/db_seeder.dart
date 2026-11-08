import 'drift_database.dart';

import '../../utlis/app_setting_X.dart';
import '../../utlis/enums.dart';

class DbSeeder {
  /// 🔹 Main entry point
  static Future<void> seedAll(Database db) async {
    await seedInitialPillData(db);
    await UserSettingsSeeder.seed(db);

    // 👇 Add future seeders here
    // await seedReminderData(db);
    // await seedSettings(db);
    // await seedUserSession(db);
  }

  /// ---------- Pill Types, Dosage Types & Default Profile ----------
  static Future<void> seedInitialPillData(Database db) async {
    const pillTypes = <String>[
      'Tablet',
      'Capsule',
      'Syrup',
      'Injection',
      'Drops',
      'Inhaler',
      'Cream',
      'Powder',
    ];
    for (final name in pillTypes) {
      await db.insert(
        'pill_types',
        {'name': name, 'is_system': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    const dosageTypes = <String>['mg', 'mcg', 'g', 'ml', 'drops', 'units'];
    for (final name in dosageTypes) {
      await db.insert(
        'dosage_types',
        {'name': name, 'is_system': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    final profileCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM profiles'),
    );
    if (profileCount == 0) {
      await db.insert('profiles', {
        'name': 'Me',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
}

class UserSettingsSeeder {
  static Future<void> seed(Database db) async {
    final batch = db.batch();
    batch.insert(
      'user_settings',
      {
        'key': AppSettingKey.theme.key,
        'value': 'system',
        'user_id': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    batch.insert(
      'user_settings',
      {
        'key': AppSettingKey.themePreset.key,
        'value': 'indigo',
        'user_id': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    batch.insert(
      'user_settings',
      {
        'key': AppSettingKey.language.key,
        'value': 'en',
        'user_id': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await batch.commit(noResult: true);
  }
}
