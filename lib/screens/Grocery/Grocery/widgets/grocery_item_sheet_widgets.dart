part of '../view/grocery_item.dart';

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.future});

  final Future<List<Map<String, dynamic>>> future;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return FractionallySizedBox(
      heightFactor: 0.82,
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
                        Text('Activity history', style: TextStyle(color: neutral.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('Every important status change and delay.', style: TextStyle(color: neutral.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final logs = snapshot.data ?? const <Map<String, dynamic>>[];
                  if (logs.isEmpty) {
                    return Center(child: Text('No activity yet', style: TextStyle(color: neutral.textSecondary)));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final log = logs[index];
                      final occurred = GroceryCatalog.dateTimeFrom(log['occurred_at']);
                      final delay = (log['delay_minutes'] as num?)?.toInt() ?? 0;
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: neutral.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: neutral.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: CenteredFaIcon(
                                  _activityIcon(log['action']?.toString()),
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _activityLabel(log['action']?.toString()),
                                    style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  if ((log['note']?.toString() ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(log['note'].toString(), style: TextStyle(color: neutral.textSecondary, fontSize: 11)),
                                  ],
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Text(
                                        occurred == null ? 'Unknown time' : DateFormat('dd MMM yyyy, h:mm a').format(occurred),
                                        style: TextStyle(color: neutral.textDisabled, fontSize: 9),
                                      ),
                                      if (delay > 0) ...[
                                        const SizedBox(width: 8),
                                        Text('${_formatDelay(delay)} late', style: const TextStyle(color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.w800)),
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

class _EmptyItems extends StatelessWidget {
  const _EmptyItems({
    required this.onAddNew,
    required this.onAddExisting,
  });

  final VoidCallback onAddNew;
  final VoidCallback onAddExisting;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        children: [
          CenteredFaIcon(
            FontAwesomeIcons.basketShopping,
            color: neutral.textDisabled,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Your grocery plan is empty',
            style: TextStyle(
              color: neutral.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Create a new item or reuse item details from one of your previous grocery plans.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onAddExisting,
                icon: const CenteredFaIcon(FontAwesomeIcons.listCheck, size: 13),
                label: const Text('Existing items'),
              ),
              FilledButton.icon(
                onPressed: onAddNew,
                icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 13),
                label: const Text('New item'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults({required this.filter});

  final String filter;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          CenteredFaIcon(FontAwesomeIcons.filter, color: neutral.textDisabled, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text('No ${_filterLabel(filter).toLowerCase()} items in this plan.', style: TextStyle(color: neutral.textSecondary))),
        ],
      ),
    );
  }
}

class _HeaderLoading extends StatelessWidget {
  const _HeaderLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: context.themeColors.neutral.card,
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _ItemsLoading extends StatelessWidget {
  const _ItemsLoading();

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Column(
      children: List.generate(
        4,
        (index) => Container(
          height: 86,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: neutral.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: neutral.divider),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

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
          const CenteredFaIcon(FontAwesomeIcons.triangleExclamation, color: AppColors.danger, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text('Could not load this grocery plan.', style: TextStyle(color: neutral.textSecondary))),
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
        Text(label, style: TextStyle(color: danger ? AppColors.danger : neutral.textPrimary)),
      ],
    ),
  );
}

String _planTypeLabel(String? type) {
  switch (type) {
    case 'weekly':
      return 'Weekly grocery';
    case 'event':
      return 'Event shopping';
    case 'custom':
      return 'Custom list';
    default:
      return 'Monthly grocery';
  }
}

String _filterLabel(String value) {
  switch (value) {
    case 'pending':
      return 'To buy';
    case 'done':
      return 'Done';
    case 'overdue':
      return 'Overdue';
    default:
      return 'All';
  }
}

Color _priorityColor(String priority) {
  switch (priority) {
    case 'urgent':
      return AppColors.danger;
    case 'high':
      return AppColors.warning;
    case 'low':
      return const Color(0xFF607D8B);
    default:
      return const Color(0xFF1565C0);
  }
}

FaIconData _itemTypeIcon(String? type) {
  switch (type) {
    case 'food':
      return FontAwesomeIcons.utensils;
    case 'fruit_veg':
      return FontAwesomeIcons.carrot;
    case 'dairy':
      return FontAwesomeIcons.bottleWater;
    case 'meat':
      return FontAwesomeIcons.drumstickBite;
    case 'bakery':
      return FontAwesomeIcons.breadSlice;
    case 'drinks':
      return FontAwesomeIcons.bottleWater;
    case 'cleaning':
      return FontAwesomeIcons.soap;
    case 'personal_care':
      return FontAwesomeIcons.soap;
    case 'household':
      return FontAwesomeIcons.house;
    default:
      return FontAwesomeIcons.basketShopping;
  }
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  final normalized = value.replaceAll('_', ' ');
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

String _formatDelay(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remaining = minutes % 60;
  if (hours < 24) return remaining == 0 ? '${hours}h' : '${hours}h ${remaining}m';
  final days = hours ~/ 24;
  final remainingHours = hours % 24;
  return remainingHours == 0 ? '${days}d' : '${days}d ${remainingHours}h';
}

String _activityLabel(String? action) {
  switch (action) {
    case 'created':
      return 'Created';
    case 'updated':
      return 'Updated';
    case 'completed':
      return 'Marked as completed';
    case 'reopened':
      return 'Reopened';
    case 'archived':
      return 'Archived';
    default:
      return _capitalize(action ?? 'Changed');
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
    default:
      return FontAwesomeIcons.plus;
  }
}
