// lib/services/restoreService.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

import 'db/drift_database.dart';

import 'backupService.dart';
import 'portable_backup_crypto.dart';
import '../screens/Settings/components/backup_password_dialog.dart';
import 'database_service.dart';
import 'db/db_config.dart';
import 'db/db_migrations.dart';

class PortableRestoreResult {
  const PortableRestoreResult({
    required this.scope,
    required this.assetCount,
    required this.restoredAssetCount,
    required this.skippedAssetCount,
  });

  final String scope;
  final int assetCount;
  final int restoredAssetCount;
  final int skippedAssetCount;
}

class DatabaseRestoreService {
  static Future<String?> extractDataFromFile() => openFileExtractData(legacyOnly: true);

  static const List<String> _preferredInsertOrder = [
    'user_settings',
    'home_feature_positions',
    'home_features',
    'meters',
    'readings',
    'meter_baseline_anchors',
    'grocery_titles',
    'grocery_items',
    'household_chores',
    'household_alerts',
    'household_activity_logs',
    'expense_titles',
    'month_closing',
    'expense_items',
    'mood_entries',
    'habits',
    'habit_progress',
    'quotations',
    'notification_settings',
    'notification_logs',
    'customers',
    'invoice_preferences',
    'invoice_business_profiles',
    'invoice_customers',
    'invoices',
    'invoice_items',
    'loans',
    'loan_transactions',
    'media_files',
    'media_collections',
    'media_collection_items',
    'media_edit_history',
    'profiles',
    'pill_types',
    'dosage_types',
    'pills',
    'schedule_rules',
    'reminder_occurrences',
    'pill_inventory',
    'occurrence_generation_tracker',
    'scan_groups',
    'scans',
    'scan_edit_history',
    // Preserve FK dependency order during portable backup restore.
    'family_trees',
    'family_members',
    'family_relationships',
    'family_memories',
    'family_member_photos',
    'family_memory_photos',
    'family_memory_people',
    'backup_restore_history',
  ];

  static Future<String?> openFileExtractData({
    BuildContext? context,
    bool legacyOnly = false,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        // allowedExtensions: const [
        //   'housezip',
        //   'zip',
        //   'housejson',
        //   'json',
        //   'db',
        //   'sqlite',
        //   'sqlite3',
        // ],
        allowMultiple: false,
        withData: false,
      );

      if (result == null || result.single.path == null) {
        return 'Restore cancelled.';
      }

      final selectedPath = result.single.path!;
      final extension = p.extension(selectedPath).toLowerCase();

      if (extension == '.db' ||
          extension == '.sqlite' ||
          extension == '.sqlite3') {
        if (!legacyOnly) return 'Old SQLite backups are restored from Legacy Backup & Compatibility.';
        await restoreLegacySqliteDatabase(File(selectedPath));
        return 'success';
      }

      final db = await DatabaseService().database;

      if (extension == '.housezip' || extension == '.zip') {
        final selectedFile = File(selectedPath);
        final header = await selectedFile.openRead(0, 8).expand((part) => part).toList();
        final encrypted = PortableBackupCrypto.hasMagic(header);
        if (legacyOnly && encrypted) {
          return 'This is a password-protected backup. Use Restore Encrypted Backup in Data Management.';
        }
        if (!legacyOnly && !encrypted) {
          return 'This is an older unencrypted backup. Use Legacy Backup & Compatibility.';
        }
        // Password authentication is retried without reopening the file picker.
        // Wrong passwords and damaged ciphertext cannot alter the database:
        // restorePortableZip authenticates before any migrations or writes.
        if (encrypted) {
          if (context == null || !context.mounted) {
            return 'A password prompt is required to restore this backup.';
          }
          String? authenticationError;
          while (context.mounted) {
            final password = await BackupPasswordDialog.restore(
              context,
              errorText: authenticationError,
            );
            if (password == null) return 'Restore cancelled.';
            try {
              final restored = await restorePortableZip(
                db,
                selectedFile,
                password: password,
              );
              return 'success:${restored.restoredAssetCount}:'
                  '${restored.skippedAssetCount}';
            } on FormatException catch (error) {
              // Only retry authentication failures. Other format errors must
              // propagate rather than being mislabeled as a wrong password.
              if (error.message !=
                  PortableBackupCrypto.authenticationFailureMessage) {
                rethrow;
              }
              authenticationError =
                  'Unable to unlock this backup. Check the password and try '
                  'again. If the password is correct, the backup file may be '
                  'damaged. No data was restored.';
            }
          }
          return 'Restore cancelled.';
        }

        final restored = await restorePortableZip(
          db,
          selectedFile,
          allowLegacy: legacyOnly,
        );
        return 'success:${restored.restoredAssetCount}:'
            '${restored.skippedAssetCount}';
      }

      if (!legacyOnly) return 'Unencrypted JSON backups are restored from Legacy Backup & Compatibility.';
      if (extension != '.json' && extension != '.housejson') {
        return 'Unsupported legacy backup type. Choose a .zip, .housezip, .json, .housejson or SQLite file.';
      }
      final selectedFile = File(selectedPath);
      final jsonText = await selectedFile.readAsString();

      await DbMigrations.checkAndUpdateSchema(db);
      await restoreFromJson(db, jsonText);

      await _recordRestoreHistory(
        db,
        scope: 'legacy_json',
        fileName: p.basename(selectedPath),
        fileSize: await selectedFile.length(),
        assetCount: 0,
        status: 'success',
        message:
            'Legacy JSON backup restored. File assets are not embedded '
            'in old JSON backups.',
      );

      return 'success';
    } catch (error, stackTrace) {
      debugPrint('Restore failed: $error\n$stackTrace');
      return 'Restore failed: $error';
    }
  }

  /// Restores a raw SQLite database created by older sqflite builds.
  ///
  /// The selected file replaces the current native database only after the
  /// SQLite header has been validated. The existing database is kept as a
  /// temporary rollback copy until Drift successfully opens and migrates the
  /// restored file.
  static Future<void> restoreLegacySqliteDatabase(File sourceFile) async {
    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'The selected legacy database does not exist.',
        sourceFile.path,
      );
    }

    final header = await sourceFile
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
    const sqliteHeader = <int>[
      0x53,
      0x51,
      0x4c,
      0x69,
      0x74,
      0x65,
      0x20,
      0x66,
      0x6f,
      0x72,
      0x6d,
      0x61,
      0x74,
      0x20,
      0x33,
      0x00,
    ];
    if (header.length < sqliteHeader.length ||
        !_bytesEqual(header.take(16), sqliteHeader)) {
      throw const FormatException(
        'The selected file is not a valid SQLite database.',
      );
    }

    final targetPath = await DbConfig.nativeDatabasePath;
    if (targetPath == null || targetPath.trim().isEmpty) {
      throw UnsupportedError(
        'Raw legacy SQLite restore is only available on native platforms. '
        'Portable .housezip/.json backups can be restored everywhere.',
      );
    }

    final target = File(targetPath);
    if (p.equals(p.absolute(sourceFile.path), p.absolute(target.path))) {
      // The user selected the active database itself. Just run the migration.
      final db = await DatabaseService().database;
      await DbMigrations.checkAndUpdateSchema(db);
      return;
    }

    await DatabaseService().close();

    final rollback = File('$targetPath.pre_drift_restore');
    if (await rollback.exists()) await rollback.delete();
    if (await target.exists()) await target.copy(rollback.path);

    try {
      await target.parent.create(recursive: true);
      await sourceFile.copy(target.path);

      // Sidecar files belong to the previous database connection and must not
      // be associated with the newly restored database.
      for (final suffix in const ['-wal', '-shm', '-journal']) {
        final sidecar = File('$targetPath$suffix');
        if (await sidecar.exists()) await sidecar.delete();
      }

      final db = await DatabaseService().database;
      await DbMigrations.checkAndUpdateSchema(db);

      await _recordRestoreHistory(
        db,
        scope: 'legacy_sqlite',
        fileName: p.basename(sourceFile.path),
        fileSize: await sourceFile.length(),
        assetCount: 0,
        status: 'success',
        message:
            'Legacy sqflite SQLite database restored and migrated to Drift.',
      );

      if (await rollback.exists()) await rollback.delete();
    } catch (_) {
      await DatabaseService().close();
      if (await rollback.exists()) {
        await rollback.copy(target.path);
        await rollback.delete();
      }
      // Ensure the previous database can be opened again before propagating
      // the original restore error.
      await DatabaseService().database;
      rethrow;
    }
  }

  static bool _bytesEqual(Iterable<int> a, List<int> b) {
    final left = a.toList(growable: false);
    if (left.length != b.length) return false;
    for (var i = 0; i < b.length; i++) {
      if (left[i] != b[i]) return false;
    }
    return true;
  }

  static Future<PortableRestoreResult> restorePortableZip(
    Database db,
    File zipFile, {
    String? password,
    bool allowLegacy = false,
  }) async {
    if (!await zipFile.exists()) {
      throw FileSystemException(
        'The selected backup file does not exist.',
        zipFile.path,
      );
    }

    final fileBytes = await zipFile.readAsBytes();
    final Uint8List zipBytes;
    if (PortableBackupCrypto.hasMagic(fileBytes)) {
      if (password == null || password.isEmpty) {
        throw const FormatException('A password is required for this encrypted backup.');
      }
      // Authenticated decryption must finish before creating restore folders or
      // mutating database records. Wrong passwords/corrupt files fail closed.
      zipBytes = await PortableBackupCrypto.decrypt(fileBytes, password);
    } else {
      if (!allowLegacy) {
        throw const FormatException(
          'This backup is not encrypted. Use Legacy Backup & Compatibility.',
        );
      }
      zipBytes = fileBytes;
    }
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final files = <String, ArchiveFile>{};

    for (final entry in archive) {
      final name = entry.name.replaceAll('\\', '/');

      if (!_isSafeArchivePath(name)) {
        throw const FormatException('The backup contains an unsafe file path.');
      }

      if (entry.isFile) {
        files[name] = entry;
      }
    }

    final manifestEntry = files['manifest.json'];
    final databaseEntry = files['database.json'];

    if (manifestEntry == null || databaseEntry == null) {
      throw const FormatException(
        'The ZIP is not a Home Helper portable backup.',
      );
    }

    final manifestBytes = _readArchiveBytes(manifestEntry, 'manifest.json');

    final databaseBytes = _readArchiveBytes(databaseEntry, 'database.json');

    final manifest = _decodeJsonMap(manifestBytes, 'manifest.json');

    if (manifest['format']?.toString() != BackupService.portableFormat) {
      throw const FormatException('Unsupported portable backup format.');
    }

    final databaseRoot = _decodeJsonMap(databaseBytes, 'database.json');

    final backupId = _safeSegment(
      manifest['backup_id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
    );

    final scope =
        manifest['scope']?.toString() ??
        databaseRoot['backup_scope']?.toString() ??
        'full_database';
    final safeScope = _safeSegment(scope);

    final assets = manifest['assets'] is List
        ? List<dynamic>.from(manifest['assets'] as List)
        : const <dynamic>[];

    // Migration is intentionally postponed until AFTER authenticated decryption
    // and format inspection. Wrong passwords must not touch the database.
    await DbMigrations.checkAndUpdateSchema(db);
    final documents = await getApplicationDocumentsDirectory();

    final restoreRoot = Directory(
      p.join(documents.path, 'HomeHelperRestored', safeScope, backupId),
    );

    await restoreRoot.create(recursive: true);

    final pathMap = <String, String>{};

    var restoredAssets = 0;
    var skippedAssets = 0;

    for (final raw in assets) {
      if (raw is! Map) {
        skippedAssets++;
        continue;
      }

      final asset = Map<String, dynamic>.from(raw);

      final originalPath = asset['original_path']?.toString();

      final archivePath = asset['archive_path']?.toString().replaceAll(
        '\\',
        '/',
      );

      if (originalPath == null ||
          originalPath.trim().isEmpty ||
          archivePath == null ||
          !_isSafeArchivePath(archivePath)) {
        skippedAssets++;
        continue;
      }

      final archiveFile = files[archivePath];

      if (archiveFile == null) {
        skippedAssets++;
        continue;
      }

      final Uint8List bytes;

      try {
        bytes = _readArchiveBytes(archiveFile, archivePath);
      } on FormatException {
        skippedAssets++;
        continue;
      }

      final expectedHash = asset['sha256']?.toString();

      if (expectedHash != null &&
          expectedHash.isNotEmpty &&
          sha256.convert(bytes).toString() != expectedHash) {
        throw FormatException(
          'Checksum verification failed for '
          '${p.basename(archivePath)}.',
        );
      }

      final destination = File(
        p.join(
          restoreRoot.path,
          _uniqueRestoredFileName(
            archivePath: archivePath,
            originalPath: originalPath,
          ),
        ),
      );

      await destination.parent.create(recursive: true);

      await destination.writeAsBytes(bytes, flush: true);

      pathMap[originalPath] = destination.path;
      restoredAssets++;
    }

    final rewrittenValue = _rewritePaths(databaseRoot, pathMap);

    if (rewrittenValue is! Map) {
      throw const FormatException(
        'The restored database structure is invalid.',
      );
    }

    final rewritten = Map<String, dynamic>.from(rewrittenValue);

    await restoreFromMap(db, rewritten);

    await _recordRestoreHistory(
      db,
      scope: scope,
      fileName: p.basename(zipFile.path),
      fileSize: zipBytes.length,
      assetCount: restoredAssets,
      status: 'success',
      message: skippedAssets == 0
          ? 'Portable backup restored with all embedded assets.'
          : 'Portable backup restored. $skippedAssets invalid or '
                'unavailable asset(s) were skipped.',
    );

    return PortableRestoreResult(
      scope: scope,
      assetCount: assets.length,
      restoredAssetCount: restoredAssets,
      skippedAssetCount: skippedAssets,
    );
  }

  static Future<void> restoreFromJson(Database db, String jsonText) async {
    final decoded = jsonDecode(jsonText);

    if (decoded is! Map) {
      throw const FormatException('The selected file is not a valid backup.');
    }

    await restoreFromMap(db, Map<String, dynamic>.from(decoded));
  }

  static Future<void> restoreFromMap(
    Database db,
    Map<String, dynamic> root,
  ) async {
    await DbMigrations.checkAndUpdateSchema(db);

    final tableNames = await _existingTables(db);

    final mergeExpenseOnly =
        root['category']?.toString() == 'expense_management_category';

    final mediaOnly =
        root['backup_scope']?.toString() == 'media_library' ||
        root['category']?.toString() == 'media_library_portable';

    final scannerOnly =
        root['backup_scope']?.toString() == 'document_scanner' ||
        root['category']?.toString() == 'document_scanner_portable';

    final backupTables = <String, List<dynamic>>{};

    for (final entry in root.entries) {
      if (entry.key != 'quotation_ai_settings' &&
          tableNames.contains(entry.key) &&
          entry.value is List) {
        backupTables[entry.key] = List<dynamic>.from(entry.value as List);
      }
    }

    if (backupTables.isEmpty) {
      throw const FormatException('No supported database tables were found.');
    }

    final foreignKeysWereEnabled =
        (Sqflite.firstIntValue(await db.rawQuery('PRAGMA foreign_keys')) ??
            0) ==
        1;

    if (foreignKeysWereEnabled) {
      await db.execute('PRAGMA foreign_keys = OFF');
    }

    try {
      await db.transaction((txn) async {
        if (mergeExpenseOnly) {
          await _mergeExpenseCategoryBackup(txn, backupTables);
          return;
        }

        if (mediaOnly) {
          await _mergeMediaBackup(txn, backupTables);
          return;
        }

        if (scannerOnly) {
          await _mergeScannerBackup(txn, backupTables);
          return;
        }

        final isLegacyInvoiceBackup =
            backupTables.containsKey('invoices') &&
            !backupTables.containsKey('invoice_business_profiles');

        if (isLegacyInvoiceBackup) {
          // Older backups did not contain reusable invoice profiles. Remove
          // current profile data so the post-restore migration can rebuild it
          // from the restored invoice snapshots exactly once.
          await txn.delete('invoice_customers');
          await txn.delete('invoice_business_profiles');
          await txn.delete('invoice_preferences');
        }

        final orderedTables = _ordered(backupTables.keys);

        for (final table in orderedTables.reversed) {
          await txn.delete(table);
        }

        for (final table in orderedTables) {
          final allowedColumns = await _tableColumns(txn, table);

          for (final rawRow in backupTables[table]!) {
            if (rawRow is! Map) continue;

            final row = _filteredRow(rawRow, allowedColumns);

            _applyCompatibilityDefaults(table, row);

            if (row.isEmpty) continue;
            if (!_rowHasUsableMedia(table, row)) continue;

            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
    } finally {
      if (foreignKeysWereEnabled) {
        await db.execute('PRAGMA foreign_keys = ON');
      }
    }

    await DbMigrations.checkAndUpdateSchema(db);
  }

  static Future<void> _mergeMediaBackup(
    DatabaseExecutor db,
    Map<String, List<dynamic>> backupTables,
  ) async {
    final mediaRows = backupTables['media_files'] ?? const <dynamic>[];
    final collectionRows =
        backupTables['media_collections'] ?? const <dynamic>[];
    final collectionItemRows =
        backupTables['media_collection_items'] ?? const <dynamic>[];
    final historyRows = backupTables['media_edit_history'] ?? const <dynamic>[];

    if (mediaRows.isEmpty) {
      throw const FormatException(
        'The media backup contains no media records.',
      );
    }

    final mediaColumns = await _tableColumns(db, 'media_files');
    final collectionColumns = await _tableColumns(db, 'media_collections');
    final collectionItemColumns = await _tableColumns(
      db,
      'media_collection_items',
    );
    final historyColumns = await _tableColumns(db, 'media_edit_history');

    final mediaIdMap = <int, int>{};
    final collectionIdMap = <int, int>{};

    for (final raw in mediaRows) {
      if (raw is! Map) continue;

      final row = _filteredRow(raw, mediaColumns);
      final oldId = _asInt(row.remove('id'));

      _applyCompatibilityDefaults('media_files', row);
      if (!_rowHasUsableMedia('media_files', row)) continue;

      row['is_deleted'] = 0;
      row['updated_at'] = DateTime.now().toIso8601String();

      final newId = await db.insert(
        'media_files',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (oldId != null) mediaIdMap[oldId] = newId;
    }

    for (final raw in collectionRows) {
      if (raw is! Map) continue;
      final row = _filteredRow(raw, collectionColumns);
      final oldId = _asInt(row.remove('id'));
      final name = row['name']?.toString().trim() ?? '';
      if (oldId == null || name.isEmpty) continue;

      final existing = await db.query(
        'media_collections',
        columns: const ['id'],
        where: 'name COLLATE NOCASE = ?',
        whereArgs: [name],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        collectionIdMap[oldId] = _asInt(existing.first['id'])!;
        continue;
      }

      final now = DateTime.now().toIso8601String();
      row['created_at'] ??= now;
      row['updated_at'] = now;
      row['sort_order'] ??= 0;
      final newId = await db.insert(
        'media_collections',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      collectionIdMap[oldId] = newId;
    }

    for (final raw in collectionItemRows) {
      if (raw is! Map) continue;
      final row = _filteredRow(raw, collectionItemColumns);
      final oldMediaId = _asInt(row['media_id']);
      final oldCollectionId = _asInt(row['collection_id']);
      final newMediaId = oldMediaId == null ? null : mediaIdMap[oldMediaId];
      final newCollectionId = oldCollectionId == null
          ? null
          : collectionIdMap[oldCollectionId];
      if (newMediaId == null || newCollectionId == null) continue;

      row['media_id'] = newMediaId;
      row['collection_id'] = newCollectionId;
      row['sort_order'] ??= 0;
      row['added_at'] ??= DateTime.now().toIso8601String();
      await db.insert(
        'media_collection_items',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    for (final raw in historyRows) {
      if (raw is! Map) continue;

      final row = _filteredRow(raw, historyColumns);
      row.remove('id');
      final oldMediaId = _asInt(row['media_id']);
      final newMediaId = oldMediaId == null ? null : mediaIdMap[oldMediaId];
      if (newMediaId == null) continue;

      row['media_id'] = newMediaId;
      if (!_rowHasUsableMedia('media_edit_history', row)) continue;

      await db.insert(
        'media_edit_history',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  static Future<void> _mergeScannerBackup(
    DatabaseExecutor db,
    Map<String, List<dynamic>> backupTables,
  ) async {
    final groupRows = backupTables['scan_groups'] ?? const <dynamic>[];
    final scanRows = backupTables['scans'] ?? const <dynamic>[];
    final historyRows = backupTables['scan_edit_history'] ?? const <dynamic>[];

    if (groupRows.isEmpty || scanRows.isEmpty) {
      throw const FormatException(
        'The scanner backup contains no document groups or pages.',
      );
    }

    final groupColumns = await _tableColumns(db, 'scan_groups');
    final scanColumns = await _tableColumns(db, 'scans');
    final historyColumns = await _tableColumns(db, 'scan_edit_history');
    final groupIdMap = <int, int>{};
    final scanIdMap = <int, int>{};
    final groupsWithPages = <int>{};
    final now = DateTime.now().toIso8601String();

    for (final raw in groupRows) {
      if (raw is! Map) continue;
      final row = _filteredRow(raw, groupColumns);
      final oldId = _asInt(row.remove('id'));
      _applyCompatibilityDefaults('scan_groups', row);
      row['updated_at'] = now;
      final newId = await db.insert(
        'scan_groups',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      if (oldId != null) groupIdMap[oldId] = newId;
    }

    for (final raw in scanRows) {
      if (raw is! Map) continue;
      final row = _filteredRow(raw, scanColumns);
      final oldId = _asInt(row.remove('id'));
      final oldGroupId = _asInt(row['group_id']);
      final newGroupId = oldGroupId == null ? null : groupIdMap[oldGroupId];
      if (newGroupId == null) continue;
      row['group_id'] = newGroupId;
      _applyCompatibilityDefaults('scans', row);
      if (!_rowHasUsableMedia('scans', row)) continue;
      row['updated_at'] = now;
      final newId = await db.insert(
        'scans',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      groupsWithPages.add(newGroupId);
      if (oldId != null) scanIdMap[oldId] = newId;
    }

    for (final raw in historyRows) {
      if (raw is! Map) continue;
      final row = _filteredRow(raw, historyColumns);
      row.remove('id');
      final oldScanId = _asInt(row['scan_id']);
      final newScanId = oldScanId == null ? null : scanIdMap[oldScanId];
      if (newScanId == null) continue;
      row['scan_id'] = newScanId;
      _applyCompatibilityDefaults('scan_edit_history', row);
      if (!_rowHasUsableMedia('scan_edit_history', row)) continue;
      await db.insert(
        'scan_edit_history',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    for (final newGroupId in groupIdMap.values) {
      if (!groupsWithPages.contains(newGroupId)) {
        await db.delete(
          'scan_groups',
          where: 'id = ?',
          whereArgs: [newGroupId],
        );
      }
    }

    if (scanIdMap.isEmpty) {
      throw const FormatException(
        'Scanner records were found, but none of their restored image files were usable.',
      );
    }
  }

  static Future<void> _mergeExpenseCategoryBackup(
    DatabaseExecutor db,
    Map<String, List<dynamic>> backupTables,
  ) async {
    final titleRows = backupTables['expense_titles'] ?? const <dynamic>[];

    if (titleRows.isEmpty) {
      throw const FormatException('The category backup has no category data.');
    }

    final titleColumns = await _tableColumns(db, 'expense_titles');

    final itemColumns = await _tableColumns(db, 'expense_items');

    final itemRows = backupTables['expense_items'] ?? const <dynamic>[];

    final importToken = DateTime.now().microsecondsSinceEpoch;

    var categoryIndex = 0;
    var itemIndex = 0;

    for (final rawTitle in titleRows) {
      if (rawTitle is! Map) continue;

      final title = _filteredRow(rawTitle, titleColumns);

      final oldCategoryId = _asInt(title.remove('id'));

      _applyCompatibilityDefaults('expense_titles', title);

      title['uuid'] = 'imported-expense-title-$importToken-${categoryIndex++}';

      title['deleted_at'] = null;
      title['updatation_date'] = DateTime.now().toIso8601String();

      final newCategoryId = await db.insert(
        'expense_titles',
        title,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      for (final rawItem in itemRows) {
        if (rawItem is! Map) continue;

        final sourceCategoryId = _asInt(rawItem['expense_id']);

        if (oldCategoryId != null && sourceCategoryId != oldCategoryId) {
          continue;
        }

        final item = _filteredRow(rawItem, itemColumns);

        item.remove('id');

        _applyCompatibilityDefaults('expense_items', item);

        item['expense_id'] = newCategoryId;
        item['closing_id'] = null;

        item['uuid'] = 'imported-expense-item-$importToken-${itemIndex++}';

        item['updatation_date'] = DateTime.now().toIso8601String();

        await db.insert(
          'expense_items',
          item,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
    }
  }

  static Map<String, dynamic> _filteredRow(
    Map<dynamic, dynamic> rawRow,
    Set<String> allowedColumns,
  ) {
    final row = <String, dynamic>{};

    for (final entry in rawRow.entries) {
      final key = entry.key.toString();

      if (allowedColumns.contains(key)) {
        row[key] = entry.value;
      }
    }

    return row;
  }

  static void _applyCompatibilityDefaults(
    String table,
    Map<String, dynamic> row,
  ) {
    if (table == 'loans') {
      final now = DateTime.now().toIso8601String();
      row['entity_name'] ??= '';
      row['loan_type'] ??= 0;
      row['amount'] ??= 0;
      row['interest_amount'] ??= 0;
      row['start_date'] ??= now;
      row['status'] ??= 0;
      row['notes'] ??= '';
      row['phone'] ??= '';
      row['address'] ??= '';
      row['category'] ??= 'General';
      row['reference_number'] ??= '';
      row['currency_code'] ??= 'PKR';
      row['installment_frequency'] ??= 'none';
      row['installment_amount'] ??= 0;
      row['reminder_enabled'] ??= 1;
      row['reminder_days_before'] ??= 3;
      row['created_at'] ??= row['start_date'];
      row['updated_at'] ??= row['created_at'];
      return;
    }

    if (table == 'loan_transactions') {
      final now = DateTime.now().toIso8601String();
      row['amount'] ??= 0;
      row['date'] ??= now;
      row['note'] ??= '';
      row['transaction_type'] ??= 'payment';
      row['payment_method'] ??= 'cash';
      row['reference_number'] ??= '';
      row['created_at'] ??= row['date'];
      return;
    }

    if (table == 'media_files') {
      final filePath = row['file_path']?.toString() ?? '';

      if (_isBlank(row['original_path'])) {
        row['original_path'] = filePath;
      }

      if (_isBlank(row['media_type'])) {
        row['media_type'] = 'image';
      }

      if (_isBlank(row['title'])) {
        row['title'] = p.basename(filePath);
      }

      row['file_size'] ??= 0;
      row['version'] ??= 1;
      row['is_favorite'] ??= 0;
      row['is_deleted'] ??= 0;
      row['created_at'] ??= DateTime.now().toIso8601String();
      row['updated_at'] ??= row['created_at'];

      return;
    }

    if (table == 'scan_groups') {
      final now = DateTime.now().toIso8601String();
      row['title'] = _isBlank(row['title']) ? 'Scanned document' : row['title'];
      row['source'] = _isBlank(row['source']) ? 'scanner' : row['source'];
      row['created_at'] ??= now;
      row['updated_at'] = _isBlank(row['updated_at'])
          ? row['created_at']
          : row['updated_at'];
      row['is_favorite'] ??= 0;
      row['tags'] ??= '';
      return;
    }

    if (table == 'scans') {
      final now = DateTime.now().toIso8601String();
      final originalPath = row['original_path']?.toString() ?? '';
      if (_isBlank(row['edited_path'])) row['edited_path'] = originalPath;
      row['created_at'] ??= now;
      row['sort_id'] ??= 0;
      row['title'] ??= '';
      row['notes'] ??= '';
      row['ocr_text'] ??= '';
      row['file_size'] ??= 0;
      row['version'] ??= 1;
      row['is_favorite'] ??= 0;
      row['updated_at'] = _isBlank(row['updated_at'])
          ? row['created_at']
          : row['updated_at'];
      return;
    }

    if (table == 'scan_edit_history') {
      row['action'] = _isBlank(row['action']) ? 'restored_edit' : row['action'];
      row['version'] ??= 1;
      row['created_at'] ??= DateTime.now().toIso8601String();
      return;
    }

    if (table == 'expense_titles') {
      final id = _asInt(row['id']) ?? 0;

      if (_isBlank(row['color'])) {
        row['color'] = _fallbackColors[id.abs() % _fallbackColors.length];
      }

      row['icon_code'] ??= _fallbackIcons[id.abs() % _fallbackIcons.length];

      if (_isBlank(row['icon_font_family'])) {
        row['icon_font_family'] = 'MaterialIcons';
      }

      row['hidden'] ??= 0;

      if (_isBlank(row['uuid'])) {
        row['uuid'] = 'legacy-expense-title-$id';
      }
    } else if (table == 'expense_items') {
      final id = _asInt(row['id']) ?? 0;

      row['price'] ??= 0;

      if (_isBlank(row['in_or_out'])) {
        row['in_or_out'] = 'Out';
      }

      if (_isBlank(row['uuid'])) {
        row['uuid'] = 'legacy-expense-item-$id';
      }
    } else if (table == 'month_closing') {
      final id = _asInt(row['id']) ?? 0;

      if (_isBlank(row['uuid'])) {
        row['uuid'] = 'legacy-month-closing-$id';
      }

      row['item_count'] ??= 0;
      row['total_in'] ??= 0;
      row['total_out'] ??= 0;
      row['is_locked'] ??= 1;
      row['closed_at'] ??= row['creation_date'];
    }
  }

  static bool _rowHasUsableMedia(String table, Map<String, dynamic> row) {
    if (table == 'media_files') {
      final editedPath = row['edited_path']?.toString().trim() ?? '';

      final filePath = row['file_path']?.toString().trim() ?? '';

      final originalPath = row['original_path']?.toString().trim() ?? '';

      final currentPath = editedPath.isNotEmpty ? editedPath : filePath;

      if (currentPath.isNotEmpty && File(currentPath).existsSync()) {
        return true;
      }

      if (originalPath.isNotEmpty && File(originalPath).existsSync()) {
        row['file_path'] = originalPath;
        row['edited_path'] = null;
        return true;
      }

      return false;
    }

    if (table == 'media_edit_history') {
      final output = row['output_path']?.toString().trim() ?? '';

      return output.isNotEmpty && File(output).existsSync();
    }

    if (table == 'scans') {
      final edited = row['edited_path']?.toString().trim() ?? '';
      final original = row['original_path']?.toString().trim() ?? '';
      if (edited.isNotEmpty && File(edited).existsSync()) return true;
      if (original.isNotEmpty && File(original).existsSync()) {
        row['edited_path'] = original;
        return true;
      }
      return false;
    }

    if (table == 'scan_edit_history') {
      final output = row['output_path']?.toString().trim() ?? '';
      return output.isNotEmpty && File(output).existsSync();
    }

    return true;
  }

  static Uint8List _readArchiveBytes(ArchiveFile file, String fileName) {
    final Uint8List? bytes = file.readBytes();

    if (bytes == null) {
      throw FormatException(
        'Could not read $fileName from the backup archive.',
      );
    }

    return bytes;
  }

  static Map<String, dynamic> _decodeJsonMap(List<int> bytes, String fileName) {
    final decoded = jsonDecode(utf8.decode(bytes));

    if (decoded is! Map) {
      throw FormatException('$fileName is not a valid JSON object.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  static dynamic _rewritePaths(dynamic value, Map<String, String> pathMap) {
    if (value is String) {
      return pathMap[value] ?? value;
    }

    if (value is List) {
      return value.map((item) => _rewritePaths(item, pathMap)).toList();
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _rewritePaths(item, pathMap)),
      );
    }

    return value;
  }

  static bool _isSafeArchivePath(String value) {
    if (value.trim().isEmpty) return false;
    if (value.startsWith('/')) return false;
    if (value.startsWith('\\')) return false;

    final normalized = p.posix.normalize(value.replaceAll('\\', '/'));

    return normalized != '..' && !normalized.startsWith('../');
  }

  static String _safeSegment(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return cleaned.isEmpty ? 'restored_asset' : cleaned;
  }

  static String _uniqueRestoredFileName({
    required String archivePath,
    required String originalPath,
  }) {
    final archiveName = p.basename(archivePath);
    final extension = p.extension(archiveName);

    final baseName = p.basenameWithoutExtension(archiveName);

    final sourceHash = sha256
        .convert(utf8.encode('$archivePath|$originalPath'))
        .toString()
        .substring(0, 12);

    final safeBase = _safeSegment(baseName);

    return '$safeBase-$sourceHash$extension';
  }

  static Future<Set<String>> _existingTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type='table' "
      "AND name NOT LIKE 'sqlite_%'",
    );

    return rows.map((row) => row['name'].toString()).toSet();
  }

  static Future<Set<String>> _tableColumns(
    DatabaseExecutor db,
    String table,
  ) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');

    return rows.map((row) => row['name'].toString()).toSet();
  }

  static List<String> _ordered(Iterable<String> tableNames) {
    final input = tableNames.toSet();

    final ordered = _preferredInsertOrder.where(input.contains).toList();

    final remaining = input.where((name) => !ordered.contains(name)).toList()
      ..sort();

    ordered.addAll(remaining);

    return ordered;
  }

  static Future<void> _recordRestoreHistory(
    Database db, {
    required String scope,
    required String fileName,
    required int fileSize,
    required int assetCount,
    required String status,
    required String message,
  }) async {
    try {
      await db.insert('backup_restore_history', {
        'operation': 'restore',
        'scope': scope,
        'file_name': fileName,
        'file_size': fileSize,
        'asset_count': assetCount,
        'status': status,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Restore history must not make the actual restore fail.
    }
  }

  static bool _isBlank(dynamic value) {
    return value == null || value.toString().trim().isEmpty;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  static const List<String> _fallbackColors = [
    '#5C6BC0',
    '#7E57C2',
    '#EC407A',
    '#EF5350',
    '#FF7043',
    '#FFA726',
    '#66BB6A',
    '#26A69A',
    '#29B6F6',
    '#78909C',
  ];

  static const List<int> _fallbackIcons = [
    57895,
    58773,
    58740,
    58732,
    58728,
    58130,
    58136,
    59475,
    58655,
    59564,
  ];
}
