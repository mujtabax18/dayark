part of '../view/pill_list_screen.dart';

class _InventoryOverview extends StatelessWidget {
  const _InventoryOverview({
    required this.total,
    required this.active,
    required this.lowStock,
  });

  final int total;
  final int active;
  final int lowStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final warning = PillUi.isDark(context)
        ? const Color(0xFFFFC65A)
        : const Color(0xFFB86D00);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PillUi.cardDecoration(
        context,
        color: PillUi.tintedSurface(context, scheme.primary, opacity: .06),
        borderColor: scheme.primary.withOpacity(.16),
        radius: 25,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medicine cabinet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Manage schedules, availability, and stock in one place.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  icon: Icons.medication_outlined,
                  label: 'Total',
                  value: total,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewStat(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Active',
                  value: active,
                  color: PillUi.statusColor(context, 'TAKEN'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OverviewStat(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low',
                  value: lowStock,
                  color: warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: PillUi.tintedSurface(context, color, opacity: .08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 7),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChoice {
  const _FilterChoice({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({
    required this.pill,
    required this.controller,
    required this.onDataChanged,
  });

  final Map<String, dynamic> pill;
  final PillListController controller;
  final VoidCallback onDataChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medicineColor = PillUi.colorFromHex(pill['color_hex']);
    final active = pill['is_active'] == 1;
    final tracks = pill['track_inventory'] == 1;
    final total = (pill['total_quantity'] as num?)?.toDouble() ?? 0;
    final remaining = (pill['remaining_quantity'] as num?)?.toDouble() ?? 0;
    final threshold =
        (pill['low_stock_threshold'] as num?)?.toDouble() ?? 0;
    final low = active && tracks && remaining <= threshold;
    final progress = total <= 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    final strength = PillUi.strengthLabel(pill);
    final lowColor = scheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PillUi.cardDecoration(
        context,
        borderColor: low
            ? lowColor.withOpacity(.34)
            : scheme.outlineVariant.withOpacity(.75),
        radius: 23,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: PillUi.tintedSurface(
                    context,
                    medicineColor,
                    opacity: .12,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  PillUi.iconForType(pill['pill_type_name']),
                  color: medicineColor,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pill['name'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.1,
                            ),
                          ),
                        ),
                        if (!active)
                          _SmallBadge(
                            label: 'Inactive',
                            color: scheme.onSurfaceVariant,
                          )
                        else if (low)
                          _SmallBadge(label: 'Low stock', color: lowColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${PillUi.doseLabel(pill)}'
                      '${strength.isEmpty ? '' : ' · $strength'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 14,
                          color: medicineColor,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            PillUi.scheduleLabel(pill),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: medicineColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Medicine options',
                onSelected: (value) => _handleMenu(context, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'EDIT',
                    child: _MenuAction(
                      icon: Icons.edit_outlined,
                      label: 'Edit medicine',
                    ),
                  ),
                  if (active && tracks)
                    const PopupMenuItem(
                      value: 'REFILL',
                      child: _MenuAction(
                        icon: Icons.add_box_outlined,
                        label: 'Refill stock',
                      ),
                    ),
                  if (active)
                    const PopupMenuItem(
                      value: 'DEACTIVATE',
                      child: _MenuAction(
                        icon: Icons.pause_circle_outline_rounded,
                        label: 'Set inactive',
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'RESTORE',
                      child: _MenuAction(
                        icon: Icons.restore_rounded,
                        label: 'Restore medicine',
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'DELETE',
                    child: _MenuAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete permanently',
                      color: scheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (!active)
            _StatusBanner(
              text: 'This medicine is inactive. Restore it to resume reminders.',
              color: scheme.onSurfaceVariant,
              icon: Icons.pause_circle_outline_rounded,
            )
          else if (!tracks)
            _StatusBanner(
              text: 'Stock tracking is turned off for this medicine.',
              color: scheme.onSurfaceVariant,
              icon: Icons.inventory_2_outlined,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_number(remaining)} remaining',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  'Alert at ${_number(threshold)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  low ? lowColor : medicineColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    final pillId = pill['id'] as int;

    if (value == 'EDIT') {
      final desktopNav = PillDesktopNavigationScope.maybeOf(context);
      if (desktopNav != null) {
        desktopNav.onOpenMedicineForm(pill);
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PillFormScreen(pill: pill)),
      );
      await controller.loadPills();
      onDataChanged();
      return;
    }

    if (value == 'REFILL') {
      final desktopNav = PillDesktopNavigationScope.maybeOf(context);
      if (desktopNav != null) {
        desktopNav.onOpenRefill(pillId, pill['name'].toString());
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PillInventoryRefillScreen(
            pillId: pillId,
            pillName: pill['name'].toString(),
          ),
        ),
      );
      await controller.loadPills();
      onDataChanged();
      return;
    }

    if (value == 'DEACTIVATE') {
      final approved = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.pause_circle_outline_rounded),
          title: const Text('Set medicine inactive?'),
          content: const Text(
            'Future reminders for this medicine will be removed. Its previous '
            'history and stock will be kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Set inactive'),
            ),
          ],
        ),
      );
      if (approved == true) {
        await controller.deactivatePill(pillId);
        onDataChanged();
      }
      return;
    }

    if (value == 'RESTORE') {
      await controller.restorePill(pillId);
      onDataChanged();
      return;
    }

    if (value == 'DELETE') {
      final scheme = Theme.of(context).colorScheme;
      final approved = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: Icon(Icons.delete_forever_rounded, color: scheme.error),
          title: const Text('Delete medicine permanently?'),
          content: Text(
            '${pill['name']} and all its reminders, Taken/Missed/Skipped '
            'history, schedules, and stock records will be permanently deleted. '
            'This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete permanently'),
            ),
          ],
        ),
      );

      if (approved != true) return;

      final messenger = ScaffoldMessenger.of(context);
      final deleted = await controller.permanentlyDeletePill(pillId);

      if (deleted) {
        onDataChanged();
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('${pill['name']} was permanently deleted.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not delete the medicine.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PillUi.tintedSurface(context, color, opacity: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MenuAction extends StatelessWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 11),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: PillUi.tintedSurface(context, color, opacity: .07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: PillUi.cardDecoration(context, radius: 23),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: PillUi.tintedSurface(context, accent, opacity: .10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 27, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
