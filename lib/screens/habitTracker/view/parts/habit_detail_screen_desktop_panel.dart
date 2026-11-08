part of '../HabitDetailScreen.dart';

class _DesktopPanel extends StatelessWidget {
  const _DesktopPanel({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final FaIconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                CenteredFaIcon(icon!, size: 15, color: AppColors.habit),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DesktopTrend extends StatelessWidget {
  const _DesktopTrend({required this.habit, required this.monthly});

  final Habit habit;
  final _MonthStats monthly;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _TrendPainter(
              values: monthly.dailyRates,
              lineColor: habit.color,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 8,
          children: [
            _Legend(
              color: habit.color,
              label: '${monthly.completed} completed',
            ),
            _Legend(
              color: AppColors.danger,
              label: '${monthly.missed} missed',
            ),
            _Legend(
              color: Colors.orange,
              label: '${monthly.skipped} skipped',
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayActionPanel extends StatelessWidget {
  const _TodayActionPanel({
    required this.habit,
    required this.progress,
    required this.scheduledToday,
    required this.canUpdateToday,
    required this.controller,
  });

  final Habit habit;
  final HabitProgress? progress;
  final bool scheduledToday;
  final bool canUpdateToday;
  final HabitTrackerController controller;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final completed = progress?.isCompleted == true;
    final skipped = progress?.isSkipped == true;
    final statusColor = completed
        ? Colors.green
        : skipped
            ? Colors.orange
            : habit.color;
    final statusText = !scheduledToday
        ? 'Rest day'
        : completed
            ? 'Completed today'
            : skipped
                ? 'Skipped today'
                : canUpdateToday
                    ? 'Waiting for update'
                    : 'Deadline passed';

    return _DesktopPanel(
      title: 'Today',
      icon: FontAwesomeIcons.circleCheck,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withOpacity(.18)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_rounded
                        : skipped
                            ? Icons.remove_rounded
                            : Icons.schedule_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        scheduledToday
                            ? 'Deadline ${TimeOfDay(hour: habit.deadlineHour, minute: habit.deadlineMinute).format(context)}'
                            : 'This habit is not scheduled today.',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (scheduledToday) ...[
            const SizedBox(height: 12),
            if (progress == null && canUpdateToday)
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => controller.recordToday(
                        habitId: habit.id!,
                        isCompleted: true,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: habit.color,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Complete'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => controller.recordToday(
                        habitId: habit.id!,
                        isCompleted: false,
                      ),
                      icon: const Icon(Icons.remove_rounded, size: 18),
                      label: const Text('Skip'),
                    ),
                  ),
                ],
              )
            else if (progress != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => controller.undoToday(habit.id!),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Clear today’s status'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _HabitConfigurationPanel extends StatelessWidget {
  const _HabitConfigurationPanel({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final days = _repeatDaysLabel(habit.repeatDays);
    final reminder = habit.notificationTime == null
        ? 'Off'
        : habit.notificationTime!.format(context);

    return _DesktopPanel(
      title: 'Habit setup',
      icon: FontAwesomeIcons.sliders,
      child: Column(
        children: [
          _InfoRow(label: 'Category', value: habit.category),
          _InfoRow(label: 'Repeat', value: days),
          _InfoRow(
            label: 'Deadline',
            value: TimeOfDay(
              hour: habit.deadlineHour,
              minute: habit.deadlineMinute,
            ).format(context),
          ),
          _InfoRow(label: 'Reminder', value: reminder),
          _InfoRow(
            label: 'Target',
            value: '${habit.targetValue} ${habit.targetUnit}',
          ),
          _InfoRow(
            label: 'Difficulty',
            value: habit.difficulty.isEmpty
                ? 'Not set'
                : '${habit.difficulty[0].toUpperCase()}${habit.difficulty.substring(1)}',
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }

  static String _repeatDaysLabel(List<int> repeatDays) {
    if (repeatDays.length == 7) return 'Every day';
    const labels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return repeatDays.map((day) => labels[day] ?? '').where((v) => v.isNotEmpty).join(', ');
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.bottomPadding = 11,
  });

  final String label;
  final String value;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: neutral.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BehaviorPlanPanel extends StatelessWidget {
  const _BehaviorPlanPanel({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    return _DesktopPanel(
      title: 'Behavior plan',
      icon: FontAwesomeIcons.route,
      child: Column(
        children: [
          if (habit.reason.isNotEmpty)
            _DesktopPlanItem(
              icon: FontAwesomeIcons.flag,
              label: 'Why',
              value: habit.reason,
              color: habit.color,
            ),
          if (habit.cue.isNotEmpty)
            _DesktopPlanItem(
              icon: FontAwesomeIcons.bolt,
              label: 'Cue',
              value: habit.cue,
              color: habit.color,
            ),
          if (habit.reward.isNotEmpty)
            _DesktopPlanItem(
              icon: FontAwesomeIcons.gift,
              label: 'Reward',
              value: habit.reward,
              color: habit.color,
              last: true,
            ),
        ],
      ),
    );
  }
}

