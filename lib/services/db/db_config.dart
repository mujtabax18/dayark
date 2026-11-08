import 'package:flutter/foundation.dart';

import 'db_path_resolver.dart';
import 'drift_database.dart';

typedef OnDbCreate = Future<void> Function(Database db, int version);
typedef OnDbOpen = Future<void> Function(Database db);
typedef OnDbUpgrade = Future<void> Function(
  Database db,
  int oldVersion,
  int newVersion,
);

class DbConfig {
  /// File name used by the old sqflite builds. Existing installations keep
  /// using this file so no user data is lost during the Drift migration.
  static const String dbName = 'meter_readings.db';

  /// New native installs use this file. Web uses [driftName] as its storage
  /// identity in OPFS / IndexedDB.
  static const String driftFileName = 'meter_readings.sqlite';
  static const String driftName = 'meter_readings';

  /// Version 21 adds local life connections, events and album-event links.
  /// Version 20 adds galleries and memory participants on top of the
  /// version 19 persistence migration, while keeping all legacy data intact.
  /// Version 19 migrated the persistence engine from sqflite to Drift while
  /// preserving the existing SQL schema and user data.
  static const int dbVersion = 21;

  static Future<String?> get nativeDatabasePath => resolveDatabasePath(
        legacyFileName: dbName,
        driftFileName: driftFileName,
      );

  static Future<Database> open({
    required OnDbCreate onCreate,
    required OnDbOpen onOpen,
    OnDbUpgrade? onUpgrade,
  }) async {
    final nativePath = await nativeDatabasePath;
    if (kDebugMode) {
      final debugLocation = nativePath ?? '${driftName}_debug (web storage)';
      debugPrint('[DayArk DEBUG] Isolated database: $debugLocation');
    }
    final db = await Database.open(
      name: kDebugMode ? '${driftName}_debug' : driftName,
      schemaVersion: dbVersion,
      nativePath: nativePath,
      shareAcrossIsolates: true,
    );

    // Drift opens the SQLite file cross-platform. The app intentionally keeps
    // its existing hand-written schema migrations, so they can repair older
    // databases created by every historical sqflite build.
    final tableCount = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
          ),
        ) ??
        0;

    if (tableCount == 0) {
      await onCreate(db, dbVersion);
    } else {
      await onOpen(db);
    }

    // onOpen is still called after a fresh create for compatibility with the
    // previous service contract (schema repair + idempotent seeders).
    if (tableCount == 0) await onOpen(db);

    await db.execute('PRAGMA user_version = $dbVersion');
    return db;
  }
}
