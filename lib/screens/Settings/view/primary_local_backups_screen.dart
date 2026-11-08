import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/device_sync/device_sync_service.dart';
import '../../../utlis/app_router.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';

void _backToSettings(BuildContext context) {
  final desktopScope = DesktopNavigationScope.maybeOf(context);
  if (MediaQuery.sizeOf(context).width >= 1100 && desktopScope != null) {
    desktopScope.onOpenRoute(RoutesStr.settings);
    return;
  }

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }

  openResponsiveModule(context, RoutesStr.settings);
}

class PrimaryLocalBackupsScreen extends ConsumerWidget {
  const PrimaryLocalBackupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deviceSyncProvider);
    final service = ref.read(deviceSyncProvider.notifier);
    final showBackLabel = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showBackLabel ? 168 : 56,
        leading: showBackLabel
            ? TextButton.icon(
                onPressed: () => _backToSettings(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Settings'),
              )
            : IconButton(
                tooltip: 'Back to Settings',
                onPressed: () => _backToSettings(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: const Text('Primary local backups'),
        actions: [
          IconButton(
            tooltip: 'Refresh restore points',
            onPressed: state.backupBusy ? null : service.refreshLocalBackups,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: service.refreshLocalBackups,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      child: Icon(Icons.settings_backup_restore_rounded),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Primary restore points',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'These backups belong only to the primary device and stay local. Sync metadata is excluded. Restoring a point makes connected secondary devices receive a fresh compressed baseline before incremental sync continues.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (state.role != SyncRole.primary)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Primary local backups are available only when this device is the primary sync device.',
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Restore points',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: state.backupBusy ||
                            state.firstSyncing ||
                            state.syncing
                        ? null
                        : service.createLocalBackup,
                    icon: state.backupBusy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: const Text('Create backup'),
                  ),
                ],
              ),
              if (state.activity != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        if (state.backupBusy) ...[
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: Text(state.activity!)),
                      ],
                    ),
                  ),
                ),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (state.localBackups.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('No primary local restore points yet.'),
                  ),
                )
              else
                ...state.localBackups.map(
                  (backup) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.restore_rounded),
                      ),
                      title: Text(_backupTitle(backup)),
                      subtitle: Text(
                        '${_formatBackupDate(backup.createdAt)} • ${_formatBytes(backup.sizeBytes)}\n${backup.fileName}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Restore this point',
                            onPressed: state.backupBusy ||
                                    state.firstSyncing ||
                                    state.syncing
                                ? null
                                : () => _confirmRestoreBackup(
                                      context,
                                      service,
                                      backup,
                                    ),
                            icon: const Icon(Icons.history_rounded),
                          ),
                          IconButton(
                            tooltip: 'Delete backup',
                            onPressed: state.backupBusy
                                ? null
                                : () => _confirmDeleteBackup(
                                      context,
                                      service,
                                      backup,
                                    ),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _backupTitle(LocalSyncBackup backup) {
    return backup.fileName.contains('before_restore')
        ? 'Safety point before restore'
        : 'Primary restore point';
  }

  static String _formatBackupDate(DateTime value) {
    final local = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }

  static Future<void> _confirmRestoreBackup(
    BuildContext context,
    DeviceSyncService service,
    LocalSyncBackup backup,
  ) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Restore this primary backup?'),
            content: Text(
              'The primary database will return to ${_formatBackupDate(backup.createdAt)}. A safety backup of the current primary state will be created first. Secondary devices will receive a fresh baseline on their next local-network connection.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) await service.restoreLocalBackup(backup);
  }

  static Future<void> _confirmDeleteBackup(
    BuildContext context,
    DeviceSyncService service,
    LocalSyncBackup backup,
  ) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete local backup?'),
            content: Text(
              'Delete the restore point from ${_formatBackupDate(backup.createdAt)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) await service.deleteLocalBackup(backup);
  }
}
