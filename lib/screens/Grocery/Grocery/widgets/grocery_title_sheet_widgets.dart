part of '../view/grocery_title.dart';

class _AlertsSheet extends StatefulWidget {
  const _AlertsSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_AlertsSheet> createState() => _AlertsSheetState();
}

class _AlertsSheetState extends State<_AlertsSheet> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = widget.ref.read(dbServiceProvider).getHouseholdAlerts();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Material(
        color: neutral.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: neutral.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Household alerts',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Due and overdue grocery items, plans, and chores.',
                          style: TextStyle(
                              color: neutral.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final alerts =
                      snapshot.data ?? const <Map<String, dynamic>>[];
                  if (alerts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CenteredFaIcon(FontAwesomeIcons.bellSlash,
                                color: neutral.textDisabled, size: 34),
                            const SizedBox(height: 12),
                            Text('No active alerts',
                                style: TextStyle(
                                    color: neutral.textPrimary,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 5),
                            Text('Your household schedule is currently clear.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: neutral.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final alert = alerts[index];
                      final severity = alert['severity']?.toString() ?? 'info';
                      final color = severity == 'critical'
                          ? AppColors.danger
                          : severity == 'warning'
                              ? AppColors.warning
                              : Theme.of(context).colorScheme.primary;
                      final isRead = alert['is_read'] == 1;
                      final dueAt =
                          GroceryCatalog.dateTimeFrom(alert['due_at']);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              isRead ? neutral.card : color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: isRead
                                  ? neutral.divider
                                  : color.withOpacity(0.25)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Center(
                                child: CenteredFaIcon(
                                  severity == 'critical'
                                      ? FontAwesomeIcons.triangleExclamation
                                      : FontAwesomeIcons.bell,
                                  color: color,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert['title']?.toString() ?? 'Alert',
                                    style: TextStyle(
                                        color: neutral.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    alert['message']?.toString() ?? '',
                                    style: TextStyle(
                                        color: neutral.textSecondary,
                                        fontSize: 11),
                                  ),
                                  if (dueAt != null) ...[
                                    const SizedBox(height: 7),
                                    Text(
                                      'Due ${DateFormat('dd MMM yyyy, h:mm a').format(dueAt)}',
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          await widget.ref
                                              .read(dbServiceProvider)
                                              .markAlertRead(
                                                alert['id'] as int,
                                                isRead: !isRead,
                                              );
                                          setState(_reload);
                                        },
                                        child: Text(isRead
                                            ? 'Mark unread'
                                            : 'Mark read'),
                                      ),
                                      TextButton(
                                        onPressed: () async {
                                          await widget.ref
                                              .read(dbServiceProvider)
                                              .dismissAlert(alert['id'] as int);
                                          setState(_reload);
                                        },
                                        child: const Text('Dismiss'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet({
    required this.service,
    this.entityType,
    this.entityId,
  });

  final dynamic service;
  final String? entityType;
  final int? entityId;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: Material(
        color: neutral.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: neutral.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Activity history',
                            style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text(
                            'Completion, reopening, updates and delay records.',
                            style: TextStyle(
                                color: neutral.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: service.getActivityLogs(
                    entityType: entityType, entityId: entityId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final logs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (logs.isEmpty) {
                    return Center(
                      child: Text('No activity recorded yet',
                          style: TextStyle(color: neutral.textSecondary)),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final log = logs[index];
                      final occurred =
                          GroceryCatalog.dateTimeFrom(log['occurred_at']);
                      final delay =
                          (log['delay_minutes'] as num?)?.toInt() ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: neutral.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: neutral.divider),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: CenteredFaIcon(
                                  _activityIcon(log['action']?.toString()),
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_capitalize(log['entity_type']?.toString() ?? 'item')} ${_activityLabel(log['action']?.toString())}',
                                    style: TextStyle(
                                        color: neutral.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12),
                                  ),
                                  if ((log['note']?.toString() ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(log['note'].toString(),
                                        style: TextStyle(
                                            color: neutral.textSecondary,
                                            fontSize: 11)),
                                  ],
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        occurred == null
                                            ? 'Unknown time'
                                            : DateFormat('dd MMM yyyy, h:mm a')
                                                .format(occurred),
                                        style: TextStyle(
                                            color: neutral.textDisabled,
                                            fontSize: 9),
                                      ),
                                      if (delay > 0) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_formatDelay(delay)} late',
                                          style: const TextStyle(
                                              color: AppColors.warning,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final FaIconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon.data,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: true,
      accent: AppColors.grocery,
    );
  }
}

class _LoadingCards extends StatelessWidget {
  const _LoadingCards({this.count = 2});

  final int count;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Column(
      children: List.generate(
        count,
        (index) => Container(
          height: 116,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: neutral.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: neutral.divider),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.danger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const CenteredFaIcon(FontAwesomeIcons.triangleExclamation,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style:
                      TextStyle(color: neutral.textSecondary, fontSize: 11))),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

PopupMenuItem<String> _menuItem(
  FaIconData icon,
  String value,
  String label,
  dynamic neutral, {
  bool danger = false,
}) {
  final color = danger ? AppColors.danger : neutral.textSecondary;
  return PopupMenuItem<String>(
    value: value,
    child: Row(
      children: [
        CenteredFaIcon(icon, size: 15, color: color),
        const SizedBox(width: 11),
        Text(label,
            style: TextStyle(
                color: danger ? AppColors.danger : neutral.textPrimary)),
      ],
    ),
  );
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final neutral = context.themeColors.neutral;
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: neutral.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const CenteredFaIcon(FontAwesomeIcons.triangleExclamation,
              color: AppColors.danger),
          title: Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(color: neutral.textPrimary)),
          content: Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: neutral.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  final normalized = value.replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _formatDelay(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours < 24)
    return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
  final days = hours ~/ 24;
  final remainingHours = hours % 24;
  return remainingHours == 0 ? '${days}d' : '${days}d ${remainingHours}h';
}

String _activityLabel(String? action) {
  switch (action) {
    case 'created':
      return 'created';
    case 'updated':
      return 'updated';
    case 'completed':
      return 'completed';
    case 'reopened':
      return 'reopened';
    case 'archived':
      return 'archived';
    case 'skipped':
      return 'skipped';
    default:
      return action ?? 'changed';
  }
}

FaIconData _activityIcon(String? action) {
  switch (action) {
    case 'completed':
      return FontAwesomeIcons.check;
    case 'reopened':
      return FontAwesomeIcons.rotateLeft;
    case 'updated':
      return FontAwesomeIcons.pen;
    case 'archived':
      return FontAwesomeIcons.boxArchive;
    case 'skipped':
      return FontAwesomeIcons.forward;
    default:
      return FontAwesomeIcons.plus;
  }
}
