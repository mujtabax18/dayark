import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'db/drift_database.dart';

import '../models/meter.dart';
import 'db/db_config.dart';
import 'db/db_migrations.dart';
import 'db/db_seeder.dart';
import 'db/db_streams.dart';
import 'diary_reminder_service.dart';

class DatabaseService {
  DatabaseService._internal();

  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static Future<Database>? _openingDatabase;

  factory DatabaseService() => _instance;

  Future<Database> get database async {
    final currentDatabase = _database;
    if (currentDatabase != null && currentDatabase.isOpen) {
      return currentDatabase;
    }

    // Prevent two providers/screens from opening and migrating the same
    // database concurrently during application startup.
    final pendingOpen = _openingDatabase;
    if (pendingOpen != null) return pendingOpen;

    final openFuture = _openDatabase();
    _openingDatabase = openFuture;

    try {
      final openedDatabase = await openFuture;
      _database = openedDatabase;
      return openedDatabase;
    } finally {
      _openingDatabase = null;
    }
  }

  Future<Database> _openDatabase() {
    return DbConfig.open(
      onCreate: (db, version) async {
        // checkAndUpdateSchema creates all tables, adds compatibility columns,
        // backfills defaults, and only then creates indexes.
        await DbMigrations.checkAndUpdateSchema(db);
        await DbSeeder.seedAll(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await DbMigrations.checkAndUpdateSchema(db);
      },
      onOpen: (db) async {
        // This also repairs databases whose version number was previously
        // updated even though an older migration failed halfway through.
        await DbMigrations.checkAndUpdateSchema(db);
        await DbSeeder.seedAll(db);
      },
    );
  }

  // Keep the same public fields so existing code remains compatible.
  final StreamController<List<Meter>> meterStreamController =
      DbStreams.meterStreamController;
  final StreamController<List<Reading>> readingStreamController =
      DbStreams.readingStreamController;

  /// Clears every application table while keeping the database schema intact.
  ///
  /// Required system defaults are seeded again afterwards so the app can keep
  /// running without a restart. The destructive Settings flow creates a full
  /// portable safety backup before calling this method.
  Future<void> clearAllTables() async {
    final db = await database;
    final foreignKeysWereEnabled =
        (Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys')) ?? 0) ==
        1;

    if (foreignKeysWereEnabled) {
      await db.execute('PRAGMA foreign_keys = OFF');
    }

    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final tables = rows
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false);

      // Delete normal app data first. Sync/runtime tables are intentionally
      // cleared last because journal triggers can write to them while normal
      // tables are being emptied.
      final normalTables = tables
          .where(
            (name) =>
                !name.startsWith('sync_') && name != 'backup_restore_history',
          )
          .toList(growable: false);
      final runtimeTables = tables
          .where(
            (name) =>
                name.startsWith('sync_') || name == 'backup_restore_history',
          )
          .toList(growable: false);

      await db.transaction((txn) async {
        for (final table in [...normalTables, ...runtimeTables]) {
          final quoted = table.replaceAll('"', '""');
          await txn.execute('DELETE FROM "$quoted"');
        }
      });

      try {
        await db.execute('DELETE FROM sqlite_sequence');
      } catch (_) {
        // sqlite_sequence does not exist until an AUTOINCREMENT table has
        // been used; there is nothing to reset in that case.
      }

      // Recreate only the tiny set of required defaults (theme/language, pill
      // lookup values and the default profile). User-created records remain
      // deleted.
      await DbSeeder.seedAll(db);

      // Native scheduled reminders are not stored only in SQLite. Remove
      // them as well so a deleted diary entry cannot still notify the user.
      // Notification cleanup is best-effort and must never turn a completed
      // database deletion into a reported failure.
      try {
        await DiaryReminderService.cancelAll();
      } catch (_) {}

      // Seeding can fire sync journal triggers on a previously paired primary.
      // Pairings were deleted above, so discard those transient journal rows.
      for (final table in const [
        'sync_ack',
        'sync_bootstrap',
        'sync_conflicts',
        'sync_journal',
        'sync_remote_row_map',
        'sync_row_identity',
        'sync_seeded_rows',
      ]) {
        if (tables.contains(table)) {
          await db.delete(table);
        }
      }
    } finally {
      if (foreignKeysWereEnabled) {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    _openingDatabase = null;

    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  void dispose() {
    DbStreams.dispose();
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
