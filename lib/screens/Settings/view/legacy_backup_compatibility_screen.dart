import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controller/backup_restore_Provider.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../../../utlis/app_router.dart';

/// All user-facing backwards compatibility is deliberately isolated here.
/// New user-created backups never take the old plaintext export route.
class LegacyBackupCompatibilityScreen extends ConsumerWidget {
  const LegacyBackupCompatibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(backupRestoreProvider.notifier);
    final status = ref.watch(backupRestoreProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legacy Backup & Compatibility'),
        leading: _isEmbeddedOnDesktop(context)
            ? IconButton(
                tooltip: 'Back to settings',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _backToSettings(context),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.warning_amber_rounded), SizedBox(width: 8), Expanded(child: Text('Older backup formats are not encrypted', style: TextStyle(fontWeight: FontWeight.w700)))]),
                  SizedBox(height: 8),
                  Text('Use this page only to import old .housezip/.zip, .housejson/.json, or SQLite .db/.sqlite/.sqlite3 files, or for compatibility exports. Old files remain unchanged. After importing, create a new encrypted portable backup from Data Management.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Action(
            icon: Icons.file_open_rounded,
            title: 'Restore older backup',
            description: 'Import an older unencrypted ZIP, JSON or SQLite backup.',
            action: () => _confirmRestore(context, () => actions.restoreLegacyBackup(context)),
          ),
          _Action(
            icon: Icons.history_rounded,
            title: 'Restore old pre-delete safety point',
            description: 'Find the latest automatic safety backup made before encryption was introduced.',
            action: () => _confirmRestore(context, () => actions.restoreLatestLegacyDeleteSafetyBackup(context)),
          ),
          _Action(
            icon: Icons.share_outlined,
            title: 'Export legacy JSON database',
            description: 'Unencrypted records-only export. Use only when an older version requires JSON.',
            action: () => _confirmPlaintext(context, () => actions.shareDatabase(context)),
          ),
          _Action(
            icon: Icons.table_rows_outlined,
            title: 'Export selected tables (legacy)',
            description: 'Advanced unencrypted database-only JSON export (no embedded file assets).',
            action: () => _exportSelected(context, actions),
          ),
          const SizedBox(height: 12),
          if (status != null) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(status))),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _backToSettings(context),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Back to encrypted backups'),
          ),
        ],
      ),
    );
  }

  static bool _isEmbeddedOnDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1100 &&
      DesktopNavigationScope.maybeOf(context) != null;

  static void _backToSettings(BuildContext context) {
    if (_isEmbeddedOnDesktop(context)) {
      DesktopNavigationScope.maybeOf(context)!.onOpenRoute(RoutesStr.settings);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutesStr.settings);
    }
  }

  static Future<void> _confirmRestore(BuildContext context, Future<void> Function() work) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Restore older backup?'),
        content: const Text('Older files were not password-encrypted. A full database restore can replace existing records. Create a new encrypted backup first for rollback.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Continue')),
        ],
      ),
    );
    if (yes == true && context.mounted) await work();
  }

  static Future<void> _confirmPlaintext(BuildContext context, Future<void> Function() work) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Create unencrypted export?'),
        content: const Text('Anyone with access to this JSON file can read its contents. This export is intended only for older versions and compatibility tools.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Export anyway')),
        ],
      ),
    );
    if (yes == true && context.mounted) await work();
  }

  static Future<void> _exportSelected(BuildContext context, BackupRestoreNotifier actions) async {
    final tables = await actions.getDatabaseTables();
    if (!context.mounted) return;
    final selected = <String>{};
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          title: const Text('Legacy selected-table export'),
          content: SizedBox(
            width: 450,
            height: 420,
            child: ListView.builder(
              itemCount: tables.length,
              itemBuilder: (_, index) {
                final table = tables[index];
                return CheckboxListTile(
                  dense: true,
                  value: selected.contains(table),
                  title: Text(table),
                  onChanged: (checked) => update(() {
                    if (checked == true) { selected.add(table); } else { selected.remove(table); }
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancel')),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(dialog, Set<String>.from(selected)),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    await _confirmPlaintext(context, () => actions.backupSelectedTables(context, result));
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.title, required this.description, required this.action});
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: action,
    ),
  );
}
