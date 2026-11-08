part of '../backupService.dart';

class BackupService {
  static const int currentBackupFormatVersion = 9;
  static const String portableFormat = 'home_helper_portable_zip';

  static const Set<String> _mediaTables = {
    'media_files',
    'media_collections',
    'media_collection_items',
    'media_edit_history',
  };

  static const Set<String> _scannerTables = {
    'scan_groups',
    'scans',
    'scan_edit_history',
  };

  static Future<List<String>> getBackupableTableNames(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name COLLATE NOCASE",
    );

    return tables
        .map((table) => table['name']?.toString())
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .where((name) => name != 'quotation_ai_settings')
        .toList(growable: false);
  }

  /// New recommended full backup. It contains database.json, manifest.json,
  /// every original/edited media asset, and any other existing file referenced
  /// by a path-like database column.
  static Future<BackupSaveResult> backupFullDataToZip(Database db, {required String password}) {
    return createAndSavePortableBackup(
      db,
      scope: PortableBackupScope.fullDatabase,
      password: password,
    );
  }

  /// Separate media-only backup. Restore merges it into the current database.
  static Future<BackupSaveResult> backupMediaLibraryToZip(Database db, {required String password}) {
    return createAndSavePortableBackup(
      db,
      scope: PortableBackupScope.mediaLibrary,
      password: password,
    );
  }

  /// Portable scanner-only backup. Restoring it merges document groups,
  /// pages, edited versions and scan history into the current database.
  static Future<BackupSaveResult> backupDocumentScannerToZip(Database db, {required String password}) {
    return createAndSavePortableBackup(
      db,
      scope: PortableBackupScope.documentScanner,
      password: password,
    );
  }

  /// Creates a full automatic restore point before destructive database work.
  ///
  /// Unlike the user-selected portable backup flow, this writes directly into
  /// the app documents folder so a cancelled file picker can never leave the
  /// user without a rollback copy.
  static Future<BackupSaveResult> createAutomaticDatabaseSafetyBackup(
    Database db,
  ) async {
    PortableBackupPackage? package;
    try {
      package = await createPortableBackup(
        db,
        scope: PortableBackupScope.fullDatabase,
      );
      // Device-only emergency restore point: encrypted using a randomly
      // generated OS-keychain secret (not a hardcoded or stored ZIP password).
      final localSecret = await LocalBackupSecret.getOrCreate();
      final protectedBytes = await PortableBackupCrypto.encrypt(package.bytes, localSecret);
      final documents = await getApplicationDocumentsDirectory();
      final directory = Directory(
        p.join(documents.path, 'DayArk', 'DatabaseSafetyBackups'),
      );
      await directory.create(recursive: true);

      final stamp = DateFormat('yyyy_MM_dd_HH_mm_ss').format(DateTime.now());
      final file = File(
        p.join(directory.path, 'before_delete_all_database_$stamp.housezip'),
      );
      await file.writeAsBytes(protectedBytes, flush: true);

      await _recordHistory(
        db,
        operation: 'backup',
        scope: 'before_delete_all_database',
        fileName: p.basename(file.path),
        fileSize: protectedBytes.length,
        assetCount: package.assetCount,
        status: 'success',
        message:
            'Encrypted safety backup created before deleting all database records.',
      );

      return BackupSaveResult._(
        status: BackupSaveStatus.saved,
        message: 'Automatic safety backup created successfully.',
        location: file.path,
        assetCount: package.assetCount,
        fileSize: protectedBytes.length,
      );
    } catch (error, stackTrace) {
      debugPrint('Automatic database safety backup failed: $error\n$stackTrace');
      await _recordFailure(
        db,
        PortableBackupScope.fullDatabase,
        package,
        error.toString(),
      );
      return BackupSaveResult.failed('Safety backup failed: $error');
    }
  }

  /// Returns the newest automatic backup created by the destructive database
  /// reset flow, or null when no safety backup exists yet.
  static Future<File?> latestAutomaticDatabaseSafetyBackup({bool legacyOnly = false}) async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(documents.path, 'DayArk', 'DatabaseSafetyBackups'),
    );
    if (!await directory.exists()) return null;

    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File &&
          p.extension(entity.path).toLowerCase() == '.housezip' &&
          p.basename(entity.path).startsWith('before_delete_all_database_')) {
        files.add(entity);
      }
    }
    if (files.isEmpty) return null;
    if (legacyOnly) {
      final unencrypted = <File>[];
      for (final file in files) {
        final header = await file.openRead(0, 8).expand((part) => part).toList();
        if (!PortableBackupCrypto.hasMagic(header)) unencrypted.add(file);
      }
      files..clear()..addAll(unencrypted);
    }
    if (files.isEmpty) return null;

    files.sort((a, b) {
      final aStat = a.statSync();
      final bStat = b.statSync();
      return bStat.modified.compareTo(aStat.modified);
    });
    return files.first;
  }

  static Future<BackupSaveResult> createAndSavePortableBackup(
    Database db, {
    required PortableBackupScope scope,
    required String password,
  }) async {
    PortableBackupPackage? package;
    try {
      package = await createPortableBackup(db, scope: scope);
      final encryptedBytes = await PortableBackupCrypto.encrypt(package.bytes, password);
      final location = await FilePicker.saveFile(
        dialogTitle: 'Save ${scope.title.toLowerCase()}',
        fileName: package.fileName,
        type: FileType.custom,
        allowedExtensions: const ['housezip'],
        bytes: encryptedBytes,
      );

      if (location == null || location.path.trim().isEmpty) {
        await _recordHistory(
          db,
          operation: 'backup',
          scope: scope.storageKey,
          fileName: package.fileName,
          fileSize: encryptedBytes.length,
          assetCount: package.assetCount,
          status: 'cancelled',
          message: 'The user cancelled the save dialog.',
        );
        return BackupSaveResult.cancelled();
      }

      final message = package.missingAssetCount == 0
          ? 'Encrypted backup saved successfully.'
          : 'Encrypted backup saved. ${package.missingAssetCount} already-missing file reference(s) were recorded in the manifest.';
      await _recordHistory(
        db,
        operation: 'backup',
        scope: scope.storageKey,
        fileName: package.fileName,
        fileSize: encryptedBytes.length,
        assetCount: package.assetCount,
        status: 'success',
        message: message,
      );
      return BackupSaveResult._(
        status: BackupSaveStatus.saved,
        message: message,
        location: location.path,
        assetCount: package.assetCount,
        fileSize: encryptedBytes.length,
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Platform error saving portable backup: $error\n$stackTrace');
      await _recordFailure(db, scope, package, error.toString());
      final lower = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (lower.contains('permission') ||
          lower.contains('denied') ||
          lower.contains('access')) {
        return BackupSaveResult.permissionDenied(
          'Android did not grant write access to that location. Choose Documents or Downloads in the system picker.',
        );
      }
      return BackupSaveResult.failed(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'The backup could not be saved.',
      );
    } catch (error, stackTrace) {
      debugPrint('Portable backup failed: $error\n$stackTrace');
      await _recordFailure(db, scope, package, error.toString());
      return BackupSaveResult.failed('Backup failed: $error');
    }
  }

  static Future<PortableBackupPackage> createPortableBackup(
    Database db, {
    required PortableBackupScope scope,
    Set<String> excludedTables = const <String>{},
    List<String> excludedTablePrefixes = const <String>[],
    Map<String, Uint8List> additionalFiles = const <String, Uint8List>{},
  }) async {
    final availableTables = (await getBackupableTableNames(db))
        .where((table) => !excludedTables.contains(table))
        .where(
          (table) => !excludedTablePrefixes.any(table.startsWith),
        )
        .toList(growable: false);
    final selectedTables = switch (scope) {
      PortableBackupScope.fullDatabase => availableTables,
      PortableBackupScope.mediaLibrary =>
        availableTables.where(_mediaTables.contains).toList(growable: false),
      PortableBackupScope.documentScanner =>
        availableTables.where(_scannerTables.contains).toList(growable: false),
    };

    if (selectedTables.isEmpty) {
      throw const FormatException('No supported tables were found for backup.');
    }

    final createdAt = DateTime.now();
    final backupId = createdAt.microsecondsSinceEpoch.toString();
    final databaseData = <String, dynamic>{
      'category': switch (scope) {
        PortableBackupScope.fullDatabase => Categories.allDataBase,
        PortableBackupScope.mediaLibrary => 'media_library_portable',
        PortableBackupScope.documentScanner => 'document_scanner_portable',
      },
      'backup_scope': scope.storageKey,
      'backup_format_version': currentBackupFormatVersion,
      'portable_format': portableFormat,
      'backup_id': backupId,
      'created_at': createdAt.toIso8601String(),
      'database_name': 'meter_readings.db',
      'included_tables': selectedTables,
      'table_count': selectedTables.length,
    };

    for (final table in selectedTables) {
      databaseData[table] = await db.query(table);
    }

    final archive = Archive();
    final assetManifest = <Map<String, dynamic>>[];
    final missingAssets = <Map<String, dynamic>>[];
    final pathToArchive = <String, String>{};
    var assetIndex = 0;

    for (final table in selectedTables) {
      final rows = databaseData[table];
      if (rows is! List) continue;

      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (row is! Map) continue;

        for (final entry in row.entries) {
          final column = entry.key.toString();
          final rawValue = entry.value;
          if (rawValue is! String || rawValue.trim().isEmpty) continue;
          if (!_looksLikeFileColumn(column)) continue;

          final sourcePath = rawValue.trim();
          final source = File(sourcePath);
          if (!await source.exists()) {
            missingAssets.add({
              'table': table,
              'row_index': rowIndex,
              'column': column,
              'original_path': sourcePath,
            });
            continue;
          }

          var archivePath = pathToArchive[sourcePath];
          if (archivePath == null) {
            final bytes = await source.readAsBytes();
            final safeBase = _safeFileName(p.basename(sourcePath));
            archivePath =
                'assets/${assetIndex.toString().padLeft(6, '0')}_$safeBase';
            assetIndex++;
            pathToArchive[sourcePath] = archivePath;
            archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
            assetManifest.add({
              'original_path': sourcePath,
              'archive_path': archivePath,
              'file_name': p.basename(sourcePath),
              'size': bytes.length,
              'sha256': sha256.convert(bytes).toString(),
            });
          }
        }
      }
    }

    for (final entry in additionalFiles.entries) {
      final name = entry.key.replaceAll('\\', '/');
      if (name.isEmpty ||
          name == 'database.json' ||
          name == 'manifest.json' ||
          name.startsWith('/') ||
          name.contains('../')) {
        throw const FormatException('Invalid additional backup file name.');
      }
      archive.addFile(ArchiveFile(name, entry.value.length, entry.value));
    }

    final databaseBytes = Uint8List.fromList(
      utf8.encode(jsonEncode(databaseData)),
    );
    archive.addFile(
      ArchiveFile('database.json', databaseBytes.length, databaseBytes),
    );

    final manifest = <String, dynamic>{
      'format': portableFormat,
      'format_version': currentBackupFormatVersion,
      'backup_id': backupId,
      'scope': scope.storageKey,
      'created_at': createdAt.toIso8601String(),
      'database_file': 'database.json',
      'asset_count': assetManifest.length,
      'missing_asset_count': missingAssets.length,
      'assets': assetManifest,
      'missing_assets': missingAssets,
    };
    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) throw StateError('ZIP encoding failed.');
    final zipBytes = Uint8List.fromList(encoded);
    final stamp = DateFormat('yyyy_MM_dd_HH_mm_ss').format(createdAt);
    final prefix = switch (scope) {
      PortableBackupScope.fullDatabase => 'home_helper_full',
      PortableBackupScope.mediaLibrary => 'home_helper_media',
      PortableBackupScope.documentScanner => 'home_helper_scanner',
    };

    return PortableBackupPackage(
      bytes: zipBytes,
      fileName: '${prefix}_$stamp.housezip',
      scope: scope,
      assetCount: assetManifest.length,
      missingAssetCount: missingAssets.length,
    );
  }

  static Future<List<int>> getPortableBackupHistory(Database db) async {
    final rows = await db.query(
      'backup_restore_history',
      orderBy: 'created_at DESC',
      limit: 100,
    );
    return rows
        .map((row) => (row['id'] as num).toInt())
        .toList(growable: false);
  }

  static Future<String?> backupAllDatabaseToJSON(Database db) async {
    try {
      final tables = await getBackupableTableNames(db);
      return backupSelectedTablesToJSON(
        db,
        tables,
        backupCategory: Categories.allDataBase,
      );
    } catch (error, stackTrace) {
      debugPrint('Error during full JSON backup: $error\n$stackTrace');
      return null;
    }
  }

  static Future<String?> backupSelectedTablesToJSON(
    Database db,
    Iterable<String> selectedTables, {
    String backupCategory = 'selected_database_tables',
  }) async {
    try {
      final availableTables = await getBackupableTableNames(db);
      final requested = selectedTables
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      final valid = availableTables
          .where(requested.contains)
          .toList(growable: false);
      if (valid.isEmpty) {
        throw const FormatException('Select at least one database table.');
      }

      final backupData = <String, dynamic>{
        'category': backupCategory,
        'backup_format_version': currentBackupFormatVersion,
        'created_at': DateTime.now().toIso8601String(),
        'database_name': 'meter_readings.db',
        'included_tables': valid,
        'table_count': valid.length,
      };
      for (final table in valid) {
        backupData[table] = await db.query(table);
      }
      return jsonEncode(backupData);
    } catch (error, stackTrace) {
      debugPrint('Error during selected-table backup: $error\n$stackTrace');
      return null;
    }
  }

  static Future<String> exportAllExpenseDataToJson(Database db) async {
    return jsonEncode({
      'category': 'expense_management',
      'backup_format_version': currentBackupFormatVersion,
      'created_at': DateTime.now().toIso8601String(),
      'included_tables': const [
        'expense_titles',
        'expense_items',
        'month_closing',
      ],
      'expense_titles': await db.query('expense_titles'),
      'expense_items': await db.query('expense_items'),
      'month_closing': await db.query('month_closing'),
    });
  }

  static Future<String> exportSpecificExpenseDataToJson(
    Database db,
    int expenseId,
  ) async {
    return jsonEncode({
      'category': 'expense_management_category',
      'backup_format_version': currentBackupFormatVersion,
      'created_at': DateTime.now().toIso8601String(),
      'included_tables': const ['expense_titles', 'expense_items'],
      'expense_titles': await db.query(
        'expense_titles',
        where: 'id = ?',
        whereArgs: [expenseId],
      ),
      'expense_items': await db.query(
        'expense_items',
        where: 'expense_id = ?',
        whereArgs: [expenseId],
        orderBy: 'date DESC, id DESC',
      ),
    });
  }

  static Future<String> exportAllGroceryDataToJson(Database db) async {
    return jsonEncode({
      'category': Categories.grocery,
      'backup_format_version': currentBackupFormatVersion,
      'createdDate': DateTime.now().toString(),
      'included_tables': const [
        'grocery_titles',
        'grocery_items',
        'household_chores',
        'household_alerts',
        'household_activity_logs',
      ],
      'grocery_titles': await db.query('grocery_titles'),
      'grocery_items': await db.query('grocery_items'),
      'household_chores': await db.query('household_chores'),
      'household_alerts': await db.query('household_alerts'),
      'household_activity_logs': await db.query('household_activity_logs'),
    });
  }

  static Future<String> exportSpecificGroceryDataToJson(
    Database db,
    int groceryId,
  ) async {
    return jsonEncode({
      'category': Categories.grocery,
      'backup_format_version': currentBackupFormatVersion,
      'createdDate': DateTime.now().toString(),
      'included_tables': const [
        'grocery_titles',
        'grocery_items',
        'household_alerts',
        'household_activity_logs',
      ],
      'grocery_titles': await db.query(
        'grocery_titles',
        where: 'id = ?',
        whereArgs: [groceryId],
      ),
      'grocery_items': await db.query(
        'grocery_items',
        where: 'grocery_id = ?',
        whereArgs: [groceryId],
        orderBy: 'status',
      ),
      'household_alerts': await db.rawQuery(
        '''
        SELECT * FROM household_alerts
        WHERE (entity_type = 'grocery_plan' AND entity_id = ?)
           OR (entity_type = 'grocery_item' AND entity_id IN
               (SELECT id FROM grocery_items WHERE grocery_id = ?))
      ''',
        [groceryId, groceryId],
      ),
      'household_activity_logs': await db.rawQuery(
        '''
        SELECT * FROM household_activity_logs
        WHERE (entity_type = 'grocery_plan' AND entity_id = ?)
           OR (entity_type = 'grocery_item' AND entity_id IN
               (SELECT id FROM grocery_items WHERE grocery_id = ?))
      ''',
        [groceryId, groceryId],
      ),
    });
  }

  /// Legacy JSON Save As API retained for existing modules.
  static Future<BackupSaveResult> saveDataToFile(
    String fileTitle,
    String jsonEncoded,
  ) async {
    if (jsonEncoded.trim().isEmpty) {
      return BackupSaveResult.failed('Backup data is empty.');
    }
    final safeTitle = _safeFileName(fileTitle);
    final stamp = DateFormat('yyyy_MM_dd_HH_mm_ss').format(DateTime.now());
    final fileName = '${safeTitle}_$stamp.housejson';
    final bytes = Uint8List.fromList(utf8.encode(jsonEncoded));

    try {
      final savedLocation = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['housejson'],
        bytes: bytes,
      );
      if (savedLocation == null || savedLocation.path.trim().isEmpty) {
        return BackupSaveResult.cancelled();
      }
      return BackupSaveResult.saved(savedLocation.path, fileSize: bytes.length);
    } on PlatformException catch (error) {
      final text = '${error.code} ${error.message ?? ''}'.toLowerCase();
      if (text.contains('permission') ||
          text.contains('denied') ||
          text.contains('access')) {
        return BackupSaveResult.permissionDenied();
      }
      return BackupSaveResult.failed(
        error.message ?? 'Backup could not be saved.',
      );
    } on FileSystemException {
      return BackupSaveResult.permissionDenied(
        'The selected location is read-only or Android blocked access.',
      );
    } catch (error) {
      return BackupSaveResult.failed('Error saving backup: $error');
    }
  }

  static Future<String?> shareJsonDataToFile(
    String jsonEncodedData, {
    String fileName = 'home_helper_backup.housejson',
    String text = 'Home Helper backup file.',
  }) async {
    try {
      if (jsonEncodedData.trim().isEmpty) return 'Backup data is empty.';
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(jsonEncodedData)),
              mimeType: 'application/json',
            ),
          ],
          fileNameOverrides: [fileName],
        ),
      );
      return 'success';
    } catch (error) {
      return 'Error sharing JSON data: $error';
    }
  }

  static bool _looksLikeFileColumn(String column) {
    final normalized = column.toLowerCase();
    return normalized == 'file_path' ||
        normalized == 'original_path' ||
        normalized == 'edited_path' ||
        normalized == 'output_path' ||
        normalized == 'source_path' ||
        normalized.endsWith('_path') ||
        normalized.endsWith('path') ||
        normalized.contains('image_path') ||
        normalized.contains('imagepath') ||
        normalized.contains('document_path') ||
        normalized.contains('audio_path') ||
        normalized.contains('video_path') ||
        normalized.contains('pdf_path');
  }

  static Future<void> _recordFailure(
    Database db,
    PortableBackupScope scope,
    PortableBackupPackage? package,
    String message,
  ) {
    return _recordHistory(
      db,
      operation: 'backup',
      scope: scope.storageKey,
      fileName: package?.fileName,
      fileSize: package?.bytes.length ?? 0,
      assetCount: package?.assetCount ?? 0,
      status: 'failed',
      message: message,
    );
  }

  static Future<void> _recordHistory(
    Database db, {
    required String operation,
    required String scope,
    String? fileName,
    int fileSize = 0,
    int assetCount = 0,
    required String status,
    String? message,
  }) async {
    try {
      await db.insert('backup_restore_history', {
        'operation': operation,
        'scope': scope,
        'file_name': fileName,
        'file_size': fileSize,
        'asset_count': assetCount,
        'status': status,
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // A legacy database may not have completed migration yet. Backup itself
      // must still be allowed to continue.
    }
  }

  static String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'backup' : cleaned;
  }
}
