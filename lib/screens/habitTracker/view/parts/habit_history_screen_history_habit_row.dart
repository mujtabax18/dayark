part of '../HabitHistoryScreen.dart';

class _HistoryHabitRow extends StatelessWidget {
  const _HistoryHabitRow({
    required this.habit,
    required this.date,
    required this.onSetStatus,
  });

  final Habit habit;
  final DateTime date;
  final ValueChanged<_HistoryAction> onSetStatus;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final progress = habit.progressFor(date);
    final isPast = _dayOnly(date).isBefore(_dayOnly(DateTime.now()));
    final editable = habit.canUpdate(date);
    final status = progress?.isCompleted == true
        ? 'Completed'
        : progress?.isSkipped == true
            ? 'Skipped'
            : isPast
                ? 'Missed'
                : 'Not updated';
    final statusColor = progress?.isCompleted == true
        ? AppColors.habit
        : progress?.isSkipped == true
            ? Colors.orange
            : isPast
                ? AppColors.danger
                : neutral.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: neutral.background.withOpacity(.42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: habit.color.withOpacity(.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: CenteredFaIcon(
                    HabitIconCatalog.fromCode(
                      habit.iconCode,
                      category: habit.category,
                      title: habit.title,
                    ),
                    color: habit.color,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (!editable && progress == null)
                Tooltip(
                  message: 'This date cannot be changed',
                  child: CenteredFaIcon(
                    FontAwesomeIcons.lock,
                    size: 13,
                    color: neutral.textDisabled,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _StatusButton(
                icon: FontAwesomeIcons.check,
                label: 'Complete',
                selected: progress?.isCompleted == true,
                enabled: editable,
                color: habit.color,
                onTap: () => onSetStatus(_HistoryAction.completed),
              ),
              _StatusButton(
                icon: FontAwesomeIcons.minus,
                label: 'Skip',
                selected: progress?.isSkipped == true,
                enabled: editable,
                color: Colors.orange,
                onTap: () => onSetStatus(_HistoryAction.skipped),
              ),
              if (progress != null)
                _StatusButton(
                  icon: FontAwesomeIcons.rotateLeft,
                  label: 'Clear',
                  selected: false,
                  enabled: editable,
                  color: neutral.textSecondary,
                  onTap: () => onSetStatus(_HistoryAction.clear),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Material(
      color: selected ? color.withOpacity(.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : neutral.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CenteredFaIcon(
                icon,
                size: 12,
                color: enabled
                    ? (selected ? color : neutral.textSecondary)
                    : neutral.textDisabled,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? (selected ? color : neutral.textPrimary)
                      : neutral.textDisabled,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectiveDayCell extends StatelessWidget {
  const _CollectiveDayCell({
    required this.day,
    required this.stats,
    this.selected = false,
    this.isToday = false,
  });

  final DateTime day;
  final _CollectiveDayStats stats;
  final bool selected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final hasStats = stats.scheduled > 0;
    Color? fill;
    Color foreground = neutral.textPrimary;

    if (hasStats && stats.completed == stats.scheduled) {
      fill = AppColors.habit.withOpacity(.16);
      foreground = AppColors.habit;
    } else if (stats.missed > 0) {
      fill = AppColors.danger.withOpacity(.09);
      foreground = AppColors.danger;
    } else if (stats.skipped > 0) {
      fill = Colors.orange.withOpacity(.10);
      foreground = Colors.orange.shade800;
    }

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: selected ? AppColors.habit.withOpacity(.18) : fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.habit
                : isToday
                    ? AppColors.habit.withOpacity(.62)
                    : Colors.transparent,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: selected ? AppColors.habit : foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
            if (hasStats)
              Positioned(
                bottom: 4,
                child: Text(
                  '${stats.completed}/${stats.scheduled}',
                  style: TextStyle(
                    color: selected ? AppColors.habit : neutral.textSecondary,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RateBadge extends StatelessWidget {
  const _RateBadge({required this.rate});
  final double rate;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.habit.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${(rate * 100).round()}%',
          style: const TextStyle(
            color: AppColors.habit,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _MonthStatChip extends StatelessWidget {
  const _MonthStatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final FaIconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CenteredFaIcon(icon, size: 11, color: color),
            const SizedBox(width: 6),
            Text(
              '$value $label',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      );
}

enum _HistoryAction { completed, skipped, clear }

class _CollectiveDayStats {
  const _CollectiveDayStats({
    required this.scheduled,
    required this.completed,
    required this.skipped,
    required this.missed,
  });

  final int scheduled;
  final int completed;
  final int skipped;
  final int missed;
}

