import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:metersystem/utlis/widgets/snackbar.dart';

import '../../../services/app_data_reset_signal.dart';
import '../../../services/backupService.dart';
import '../../../services/database_service.dart';
import '../../../services/device_sync/device_sync_service.dart';
import '../../../services/restoreService.dart';
import '../../../services/portable_backup_crypto.dart';
import '../components/backup_password_dialog.dart';

class BackupRestoreNotifier extends StateNotifier<String?> {
  BackupRestoreNotifier(this.ref) : super(null);

  final Ref ref;

  Future<List<String>> getDatabaseTables() async {
    final db = await DatabaseService().database;
    return BackupService.getBackupableTableNames(db);
  }

  Future<void> backupDatabase(BuildContext context) async {
    final password = await BackupPasswordDialog.create(context);
    if (password == null || !context.mounted) return;
    state = 'Preparing a portable full backup with database and files...';
    final db = await DatabaseService().database;
    final result = await BackupService.backupFullDataToZip(db, password: password);
    _handleSaveResult(context, result, title: 'Full backup complete');
  }

  Future<void> backupMediaLibrary(BuildContext context) async {
    final password = await BackupPasswordDialog.create(context);
    if (password == null || !context.mounted) return;
    state = 'Preparing media studio backup with originals and edit history...';
    final db = await DatabaseService().database;
    final result = await BackupService.backupMediaLibraryToZip(db, password: password);
    _handleSaveResult(context, result, title: 'Media backup complete');
  }

  Future<void> backupDocumentScanner(BuildContext context) async {
    final password = await BackupPasswordDialog.create(context);
    if (password == null || !context.mounted) return;
    state = 'Preparing document scanner backup with all page images...';
    final db = await DatabaseService().database;
    final result = await BackupService.backupDocumentScannerToZip(db, password: password);
    _handleSaveResult(context, result, title: 'Scanner backup complete');
  }

  Future<void> backupSelectedTables(
    context,
    Iterable<String> selectedTables,
  ) async {
    final tables = selectedTables.toSet().toList()..sort();
    if (tables.isEmpty) {
      _failure(
        context,
        'No tables selected',
        'Select at least one table to create a backup.',
      );
      return;
    }

    state = 'Preparing backup for ${tables.length} table(s)...';

    final db = await DatabaseService().database;
    final backup = await BackupService.backupSelectedTablesToJSON(db, tables);
    if (backup == null) {
      _failure(
        context,
        'Backup failed',
        'Could not create the selected-table backup.',
      );
      return;
    }

    state = 'Choose where to save the selected-table backup.';
    final result = await BackupService.saveDataToFile(
      'selected_tables_${tables.length}',
      backup,
    );
    _handleSaveResult(
      context,
      result,
      title: 'Selected tables backed up',
    );
  }

  Future<void> shareDatabase(context) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.backupAllDatabaseToJSON(db);
    if (backup == null) {
      _failure(context, 'Share failed', 'Could not create the backup.');
      return;
    }
    final result = await BackupService.shareJsonDataToFile(
      backup,
      fileName: 'home_helper_full_backup.housejson',
      text: 'Home Helper full database backup.',
    );
    _handleShareResult(context, result, 'Full database backup shared.');
  }

  Future<void> backupExpenses(context) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportAllExpenseDataToJson(db);
    final result = await BackupService.saveDataToFile('expenses', backup);
    _handleSaveResult(context, result, title: 'Expense backup complete');
  }

  Future<void> shareExpenses(context) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportAllExpenseDataToJson(db);
    final result = await BackupService.shareJsonDataToFile(
      backup,
      fileName: 'expense_backup.housejson',
      text: 'Expense management backup including categories and closings.',
    );
    _handleShareResult(context, result, 'Expense backup shared.');
  }

  Future<void> backupExpenseCategory(context, int id) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportSpecificExpenseDataToJson(db, id);
    final result =
        await BackupService.saveDataToFile('expense_category', backup);
    _handleSaveResult(context, result, title: 'Category backup complete');
  }

  Future<void> shareExpenseCategory(context, int id) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportSpecificExpenseDataToJson(db, id);
    final result = await BackupService.shareJsonDataToFile(
      backup,
      fileName: 'expense_category_$id.housejson',
      text: 'Expense category backup.',
    );
    _handleShareResult(context, result, 'Expense category shared.');
  }

  Future<void> restoreDatabase(context) async {
    state = 'Choose a password-encrypted .housezip backup.';
    final result = await DatabaseRestoreService.openFileExtractData(context: context);
    if (result == 'success' || result?.startsWith('success:') == true) {
      var message =
          'Data restored successfully. The app data views were refreshed automatically.';
      if (result?.startsWith('success:') == true) {
        final parts = result!.split(':');
        final restored = parts.length > 1 ? parts[1] : '0';
        final skipped = parts.length > 2 ? parts[2] : '0';
        message = '$restored embedded file(s) restored; $skipped skipped. '
            'Database records were updated successfully.';
      }
      _success(context, 'Restore complete', message);
      AppDataResetSignal.instance.notifyReset();
      return;
    }
    if (result == 'Restore cancelled.') {
      state = result;
      return;
    }
    _failure(context, 'Restore failed', result ?? 'Restore failed.');
  }

  Future<void> restoreLegacyBackup(BuildContext context) async {
    state = 'Choose an older unencrypted ZIP, JSON, or SQLite backup.';
    final result = await DatabaseRestoreService.openFileExtractData(
      context: context,
      legacyOnly: true,
    );
    if (result == 'success' || result?.startsWith('success:') == true) {
      _success(context, 'Legacy restore complete',
          'Your older backup was restored. Create a new password-encrypted portable backup to protect it.');
      AppDataResetSignal.instance.notifyReset();
    } else if (result == 'Restore cancelled.') {
      state = result;
    } else {
      _failure(context, 'Legacy restore failed', result ?? 'Restore failed.');
    }
  }

  Future<void> restoreLatestLegacyDeleteSafetyBackup(BuildContext context) async {
    try {
      final backup = await BackupService.latestAutomaticDatabaseSafetyBackup(legacyOnly: true);
      if (backup == null) {
        _failure(context, 'Not found', 'No older unencrypted delete safety backup is available.');
        return;
      }
      final db = await DatabaseService().database;
      await DatabaseRestoreService.restorePortableZip(db, backup, allowLegacy: true);
      _success(context, 'Legacy safety backup restored',
          'The previous safety backup was restored. Create a new encrypted portable backup.');
      AppDataResetSignal.instance.notifyReset();
    } catch (error) {
      _failure(context, 'Legacy restore failed', '$error');
    }
  }

  Future<void> restoreExpenses(context) => restoreDatabase(context);

  // Grocery methods are kept so other parts of the app are unaffected.
  Future<void> backUpAllGroceries(context) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportAllGroceryDataToJson(db);
    final result =
        await BackupService.saveDataToFile('allGroceries', backup);
    _handleSaveResult(context, result, title: 'Grocery backup complete');
  }

  Future<void> backUpGroceries(context, int id) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportSpecificGroceryDataToJson(db, id);
    final result = await BackupService.saveDataToFile('grocery', backup);
    _handleSaveResult(context, result, title: 'Grocery backup complete');
  }

  Future<void> shareAllGroceries(context) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportAllGroceryDataToJson(db);
    final result = await BackupService.shareJsonDataToFile(
      backup,
      fileName: 'grocery_backup.housejson',
      text: 'Grocery backup.',
    );
    _handleShareResult(context, result, 'Grocery backup shared.');
  }

  Future<void> shareGroceries(context, int id) async {
    final db = await DatabaseService().database;
    final backup = await BackupService.exportSpecificGroceryDataToJson(db, id);
    final result = await BackupService.shareJsonDataToFile(
      backup,
      fileName: 'grocery_$id.housejson',
      text: 'Grocery list backup.',
    );
    _handleShareResult(context, result, 'Grocery backup shared.');
  }

  Future<void> restoreGroceries(context) => restoreDatabase(context);

  /// Creates an automatic full portable restore point first, then removes all
  /// user-created database records. Deletion never starts when backup creation
  /// fails.
  Future<bool> deleteAllDatabaseWithSafetyBackup(context) async {
    try {
      state = 'Creating a full safety backup before database deletion...';
      final db = await DatabaseService().database;
      final backupResult =
          await BackupService.createAutomaticDatabaseSafetyBackup(db);

      if (!backupResult.isSaved ||
          backupResult.location == null ||
          backupResult.location!.isEmpty) {
        _failure(
          context,
          'Database was not deleted',
          'The automatic safety backup could not be created. No database data was removed. ${backupResult.message}',
        );
        return false;
      }

      state = 'Safety backup complete. Stopping local sync...';
      await ref.read(deviceSyncProvider.notifier).disconnect(forgetPeers: true);

      state = 'Safety backup complete. Deleting all database records...';
      await DatabaseService().clearAllTables();

      final message =
          'All database records were deleted and the app was reset to the fresh database state. A safety backup was created first at ${backupResult.location}. You can restore it from Settings → Data Management.';
      _success(context, 'Database cleared safely', message);

      // Recreate the application data scope after the current operation has
      // completed. This clears cached rows from Grocery, Home summaries,
      // invoices, meters, diary, habits, scanner, media, loans, quotations,
      // pills, and any other database-backed provider or desktop selection.
      AppDataResetSignal.instance.notifyReset();
      return true;
    } catch (error) {
      _failure(
        context,
        'Database was not deleted',
        'The operation stopped safely: $error',
      );
      return false;
    }
  }

  Future<void> restoreLatestDeleteSafetyBackup(context) async {
    try {
      state = 'Looking for the latest automatic delete safety backup...';
      final backup = await BackupService.latestAutomaticDatabaseSafetyBackup();
      if (backup == null || !await backup.exists()) {
        _failure(
          context,
          'No safety backup found',
          'No automatic backup created by Delete All Database is available yet.',
        );
        return;
      }

      state = 'Restoring ${backup.path.split(RegExp(r'[\\/]')).last}...';
      final db = await DatabaseService().database;
      final bytes = await backup.openRead(0, 8).expand((part) => part).toList();
      if (!PortableBackupCrypto.hasMagic(bytes)) {
        _failure(context, 'Legacy safety backup',
            'This is an older unencrypted backup. Use the Legacy Backup & Compatibility page to restore it.');
        return;
      }
      final secret = await LocalBackupSecret.requireExisting();
      final result = await DatabaseRestoreService.restorePortableZip(db, backup, password: secret);
      _success(
        context,
        'Safety backup restored',
        'The latest pre-delete database backup was restored successfully. ${result.restoredAssetCount} embedded file(s) restored and ${result.skippedAssetCount} skipped.',
      );
      AppDataResetSignal.instance.notifyReset();
    } catch (error) {
      _failure(
        context,
        'Restore failed',
        'Could not restore the latest delete safety backup: $error',
      );
    }
  }

  /// Kept for older callers. It now follows the same safety rule and creates
  /// an automatic full backup before clearing database records.
  Future<void> clearDatabase() async {
    final db = await DatabaseService().database;
    final backupResult =
        await BackupService.createAutomaticDatabaseSafetyBackup(db);
    if (!backupResult.isSaved) {
      throw StateError(
        'Database was not cleared because the safety backup failed: ${backupResult.message}',
      );
    }
    await ref.read(deviceSyncProvider.notifier).disconnect(forgetPeers: true);
    await DatabaseService().clearAllTables();
    state = 'Database cleared successfully after creating a safety backup.';
    AppDataResetSignal.instance.notifyReset();
  }

  void _handleSaveResult(
    context,
    BackupSaveResult result, {
    required String title,
  }) {
    switch (result.status) {
      case BackupSaveStatus.saved:
        final message = result.location == null || result.location!.isEmpty
            ? 'Backup saved in the selected location.'
            : 'Backup saved successfully. Location: ${result.location}';
        _success(context, title, message);
        return;
      case BackupSaveStatus.cancelled:
        state = result.message;
        return;
      case BackupSaveStatus.permissionDenied:
        _failure(context, 'Storage access denied', result.message);
        return;
      case BackupSaveStatus.failed:
        _failure(context, 'Backup failed', result.message);
        return;
    }
  }

  void _handleShareResult(context, String? result, String successMessage) {
    if (result == 'success') {
      _success(context, 'Sharing complete', successMessage);
    } else {
      _failure(context, 'Sharing failed', result ?? 'Could not share backup.');
    }
  }

  void _success(context, String title, String message) {
    showSnackbar(context, title, message, ContentType.success);
    state = message;
  }

  void _failure(context, String title, String message) {
    showSnackbar(context, title, message, ContentType.failure);
    state = message;
  }
}

final backupRestoreProvider =
    StateNotifierProvider<BackupRestoreNotifier, String?>(
  (ref) => BackupRestoreNotifier(ref),
);
