import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../controller/mediaController.dart';
import '../../services/backupService.dart';
import '../../services/database_service.dart';
import '../../services/restoreService.dart';
import '../scanner/controllers/provideers/scanGroupRepoProvider.dart';
import '../Settings/components/backup_password_dialog.dart';

class MediaBackupRestoreScreen extends ConsumerStatefulWidget {
  const MediaBackupRestoreScreen({super.key});

  @override
  ConsumerState<MediaBackupRestoreScreen> createState() =>
      _MediaBackupRestoreScreenState();
}

class _MediaBackupRestoreScreenState
    extends ConsumerState<MediaBackupRestoreScreen> {
  bool _busy = false;
  String? _status;
  late Future<List<Map<String, Object?>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        title: const Text('Backup and restore'),
        backgroundColor: neutral.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.24),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Password-encrypted portable backups include database records, original media, every edited version and an integrity-protected manifest. Restored file paths are rewritten to valid local paths.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ActionCard(
            icon: Icons.perm_media_outlined,
            title: 'Backup media studio',
            subtitle:
                'Creates a separate .housezip containing media records, originals, edits and version history. Restoring it merges media into the current app.',
            buttonText: 'Create media ZIP',
            onPressed: _busy ? null : _backupMedia,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.document_scanner_outlined,
            title: 'Backup document scanner',
            subtitle:
                'Creates a scanner-only .housezip containing document groups, every page, edits, notes, OCR text and page order. Restoring it safely merges documents.',
            buttonText: 'Create scanner ZIP',
            onPressed: _busy ? null : _backupScanner,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.inventory_2_outlined,
            title: 'Backup complete app',
            subtitle:
                'Creates a full portable .housezip with all database tables and every existing file referenced by a path column.',
            buttonText: 'Create full ZIP',
            onPressed: _busy ? null : _backupFull,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.settings_backup_restore,
            title: 'Restore backup',
            subtitle:
                'Restores .housezip/.zip backups, legacy JSON, and older sqflite .db/.sqlite databases. Old JSON cannot contain image bytes that were never backed up.',
            buttonText: 'Choose backup file',
            onPressed: _busy ? null : _restore,
          ),
          if (_busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
          if (_status != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: neutral.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: neutral.divider),
              ),
              child: Text(_status!),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Restore behavior',
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• Media-only backups merge into the current media library.\n'
            '• Scanner-only backups merge groups, pages and edit history.\n'
            '• Full backups replace the backed-up tables.\n'
            '• Files are checksum-verified before records are restored.\n'
            '• Unsafe ZIP paths are rejected.\n'
            '• Missing legacy paths are skipped instead of creating invalid media rows.',
            style: TextStyle(color: neutral.textSecondary, height: 1.55),
          ),
          const SizedBox(height: 24),
          Text(
            'Backup and restore history',
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  'History could not be loaded: ${snapshot.error}',
                  style: TextStyle(color: neutral.textSecondary),
                );
              }
              final rows = snapshot.data ?? const <Map<String, Object?>>[];
              if (rows.isEmpty) {
                return Text(
                  'No backup or restore operations recorded yet.',
                  style: TextStyle(color: neutral.textSecondary),
                );
              }
              return Column(
                children: rows
                    .map((row) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _BackupHistoryCard(row: row),
                        ))
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _backupMedia() async {
    await _run(() async {
      final db = await ref.read(databaseServiceProvider).database;
      final password = await BackupPasswordDialog.create(context);
      if (password == null || !mounted) return 'Backup cancelled.';
      final result = await BackupService.backupMediaLibraryToZip(db, password: password);
      return _backupMessage(result);
    });
  }

  Future<void> _backupScanner() async {
    await _run(() async {
      final db = await ref.read(databaseServiceProvider).database;
      final password = await BackupPasswordDialog.create(context);
      if (password == null || !mounted) return 'Backup cancelled.';
      final result = await BackupService.backupDocumentScannerToZip(db, password: password);
      return _backupMessage(result);
    });
  }

  Future<void> _backupFull() async {
    await _run(() async {
      final db = await ref.read(databaseServiceProvider).database;
      final password = await BackupPasswordDialog.create(context);
      if (password == null || !mounted) return 'Backup cancelled.';
      final result = await BackupService.backupFullDataToZip(db, password: password);
      return _backupMessage(result);
    });
  }

  Future<void> _restore() async {
    await _run(() async {
      final result = await DatabaseRestoreService.openFileExtractData(context: context);
      refreshMediaLibrary(ref);
      ref.invalidate(scanGroupPreviewProvider);
      ref.invalidate(filteredScanGroupPreviewProvider);
      if (result == null) return 'No result was returned.';
      if (result.startsWith('success:')) {
        final parts = result.split(':');
        final restored = parts.length > 1 ? parts[1] : '0';
        final skipped = parts.length > 2 ? parts[2] : '0';
        return 'Restore completed. $restored asset(s) restored; $skipped skipped.';
      }
      if (result == 'success') return 'Restore completed successfully.';
      return result;
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final message = await action();
      if (mounted) {
        setState(() {
          _status = message;
          _historyFuture = _loadHistory();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Operation failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<Map<String, Object?>>> _loadHistory() async {
    final db = await ref.read(databaseServiceProvider).database;
    return db.query(
      'backup_restore_history',
      orderBy: 'created_at DESC, id DESC',
      limit: 20,
    );
  }

  String _backupMessage(BackupSaveResult result) {
    if (!result.isSaved) return result.message;
    final mb = result.fileSize / (1024 * 1024);
    return '${result.message} ${result.assetCount} asset(s), ${mb.toStringAsFixed(2)} MB.';
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: neutral.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.save_alt),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _BackupHistoryCard extends StatelessWidget {
  const _BackupHistoryCard({required this.row});

  final Map<String, Object?> row;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final operation = row['operation']?.toString() ?? 'operation';
    final scope = (row['scope']?.toString() ?? 'unknown').replaceAll('_', ' ');
    final status = row['status']?.toString() ?? 'unknown';
    final assets = row['asset_count']?.toString() ?? '0';
    final parsed = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final date = parsed == null
        ? 'Unknown date'
        : DateFormat('MMM d, yyyy • HH:mm').format(parsed);
    final succeeded = status == 'success';
    final title = operation.isEmpty
        ? 'Operation'
        : '${operation[0].toUpperCase()}${operation.substring(1)}';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            succeeded ? Icons.check_circle_outline : Icons.info_outline,
            color: succeeded ? Colors.green : neutral.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title • $scope',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$date • $assets asset(s) • $status',
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (row['message']?.toString().trim().isNotEmpty == true) ...[
                  const SizedBox(height: 5),
                  Text(
                    row['message'].toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
