import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';

import 'database_service.dart';
import 'db/db_config.dart';
import 'restoreService.dart';

class OnlineDatabaseLoader {
  static final Dio _dio = Dio();

  /// Download a raw SQLite backup from the server to a temporary file.
  static Future<File> downloadBackup({
    required String url,
    required String token,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, 'cloud_restore.db');

    await _dio.download(
      url,
      tempPath,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return File(tempPath);
  }

  /// Restores server-downloaded databases through the same validated legacy
  /// SQLite path used by local restore. This closes Drift safely, replaces the
  /// native file, migrates it, and rolls back on failure.
  static Future<void> restoreDatabase(File downloadedDb) async {
    await DatabaseRestoreService.restoreLegacySqliteDatabase(downloadedDb);
  }

  /// Exposes the active native file path for diagnostics/cloud-backup code.
  /// Returns null on web where Drift persists in OPFS / IndexedDB.
  static Future<String?> get activeNativeDatabasePath =>
      DbConfig.nativeDatabasePath;
}
