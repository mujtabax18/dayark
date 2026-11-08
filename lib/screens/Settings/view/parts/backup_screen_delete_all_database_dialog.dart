part of '../backupScreen.dart';

class _DeleteAllDatabaseDialog extends StatefulWidget {
  const _DeleteAllDatabaseDialog();

  @override
  State<_DeleteAllDatabaseDialog> createState() =>
      _DeleteAllDatabaseDialogState();
}

class _DeleteAllDatabaseDialogState extends State<_DeleteAllDatabaseDialog> {
  static const int _initialSeconds = 3;
  Timer? _timer;
  int _remainingSeconds = _initialSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDelete = _remainingSeconds == 0;

    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 34),
      title: const Text('Delete all database records?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This removes all user-created database data from every module. '
              'Before anything is deleted, the app will automatically create '
              'a complete portable safety backup including database records '
              'and referenced local files.',
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withOpacity(.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.error.withOpacity(.28)),
              ),
              child: Text(
                canDelete
                    ? 'The delete button is now available. The database will only be cleared if the safety backup succeeds.'
                    : 'Please review this action. Delete becomes available in $_remainingSeconds second${_remainingSeconds == 1 ? '' : 's'}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: canDelete ? () => Navigator.pop(context, true) : null,
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          icon: canDelete
              ? const Icon(Icons.delete_forever_rounded)
              : const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          label: Text(
            canDelete ? 'Delete All Database' : 'Delete in $_remainingSeconds',
          ),
        ),
      ],
    );
  }
}

enum _SettingsSection {
  appearance,
  dashboard,
  learning,
  data,
  updates,
  about,
}

class _SettingsResponsiveFrame extends StatelessWidget {
  const _SettingsResponsiveFrame({
    required this.child,
    required this.onSectionSelected,
  });

  final Widget child;
  final ValueChanged<_SettingsSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1100) return child;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 260,
              child: ColoredBox(
                color: scheme.surface,
                child: _SettingsDesktopIndex(
                  onSectionSelected: onSectionSelected,
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _SettingsDesktopIndex extends StatelessWidget {
  const _SettingsDesktopIndex({
    required this.onSectionSelected,
  });

  final ValueChanged<_SettingsSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = <_SettingsIndexItem>[
      _SettingsIndexItem(
        _SettingsSection.appearance,
        Icons.palette_outlined,
        'Appearance',
        'Theme, language and currency',
      ),
      _SettingsIndexItem(
        _SettingsSection.dashboard,
        Icons.space_dashboard_outlined,
        'Dashboard',
        'Home and navigation layout',
      ),
      _SettingsIndexItem(
        _SettingsSection.learning,
        Icons.school_outlined,
        'Learning',
        'Tutorials and sample data',
      ),
      _SettingsIndexItem(
        _SettingsSection.data,
        Icons.storage_outlined,
        'Data',
        'Backup, restore and database',
      ),
      _SettingsIndexItem(
        _SettingsSection.updates,
        Icons.system_update_alt_rounded,
        'Updates',
        'Application update options',
      ),
      _SettingsIndexItem(
        _SettingsSection.about,
        Icons.info_outline_rounded,
        'About',
        'Application information',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure the desktop workspace and app preferences.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 22),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSectionSelected(item.section),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: scheme.surface,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withOpacity(.58),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item.icon,
                            size: 18,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withOpacity(.30),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.desktop_windows_outlined,
                  size: 19,
                  color: scheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Desktop uses the admin-panel layout. Mobile keeps the existing navigation and screen flow.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsIndexItem {
  const _SettingsIndexItem(
    this.section,
    this.icon,
    this.title,
    this.subtitle,
  );

  final _SettingsSection section;
  final IconData icon;
  final String title;
  final String subtitle;
}

