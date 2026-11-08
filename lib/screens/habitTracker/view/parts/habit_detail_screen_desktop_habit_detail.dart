part of '../HabitDetailScreen.dart';

class _DesktopHabitDetail extends StatelessWidget {
  const _DesktopHabitDetail({
    required this.habit,
    required this.monthly,
    required this.controller,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onEditDate,
  });

  final Habit habit;
  final _MonthStats monthly;
  final HabitTrackerController controller;
  final Future<void> Function() onEdit;
  final Future<void> Function() onToggleActive;
  final Future<void> Function() onDelete;
  final ValueChanged<DateTime> onEditDate;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final now = DateTime.now();
    final todayProgress = habit.progressFor(now);
    final scheduledToday = habit.isScheduledOn(now);
    final canUpdateToday = habit.isActive && habit.canUpdate(now);

    return ColoredBox(
      color: neutral.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 34),
            children: [
              _DesktopDetailHeader(
                habit: habit,
                onEdit: onEdit,
                onToggleActive: onToggleActive,
                onDelete: onDelete,
              ),
              const SizedBox(height: 20),
              _DesktopKpiGrid(habit: habit, monthly: monthly),
              const SizedBox(height: 20),
              if (constraints.maxWidth >= 940)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        children: [
                          _DesktopPanel(
                            title: 'Monthly performance',
                            subtitle:
                                'Completion trend and status distribution for the current month.',
                            child: _DesktopTrend(
                              habit: habit,
                              monthly: monthly,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _DesktopPanel(
                            title: 'Habit calendar',
                            subtitle:
                                'Select today or a previous scheduled day to change its status.',
                            child: HabitCalendar(
                              habit: habit,
                              onDaySelected: onEditDate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _TodayActionPanel(
                            habit: habit,
                            progress: todayProgress,
                            scheduledToday: scheduledToday,
                            canUpdateToday: canUpdateToday,
                            controller: controller,
                          ),
                          const SizedBox(height: 16),
                          _HabitConfigurationPanel(habit: habit),
                          if (HabitDetailScreen._hasPlan(habit)) ...[
                            const SizedBox(height: 16),
                            _BehaviorPlanPanel(habit: habit),
                          ],
                          const SizedBox(height: 16),
                          _DesktopPanel(
                            title: 'Coach insight',
                            icon: FontAwesomeIcons.lightbulb,
                            child: Text(
                              HabitDetailScreen._coachInsight(habit, monthly),
                              style: TextStyle(
                                color: neutral.textSecondary,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _TodayActionPanel(
                      habit: habit,
                      progress: todayProgress,
                      scheduledToday: scheduledToday,
                      canUpdateToday: canUpdateToday,
                      controller: controller,
                    ),
                    const SizedBox(height: 16),
                    _DesktopPanel(
                      title: 'Monthly performance',
                      child: _DesktopTrend(habit: habit, monthly: monthly),
                    ),
                    const SizedBox(height: 16),
                    _DesktopPanel(
                      title: 'Habit calendar',
                      child: HabitCalendar(
                        habit: habit,
                        onDaySelected: onEditDate,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _HabitConfigurationPanel(habit: habit),
                    if (HabitDetailScreen._hasPlan(habit)) ...[
                      const SizedBox(height: 16),
                      _BehaviorPlanPanel(habit: habit),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DesktopDetailHeader extends StatelessWidget {
  const _DesktopDetailHeader({
    required this.habit,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final Habit habit;
  final Future<void> Function() onEdit;
  final Future<void> Function() onToggleActive;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: habit.color.withOpacity(.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: habit.color.withOpacity(.20)),
          ),
          child: CenteredFaIcon(
            HabitIconCatalog.fromCode(
              habit.iconCode,
              category: habit.category,
              title: habit.title,
            ),
            color: habit.color,
            size: 23,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: neutral.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(active: habit.isActive),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                habit.description?.trim().isNotEmpty == true
                    ? habit.description!.trim()
                    : '${habit.category} · Keep showing up one day at a time.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: neutral.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 18),
        OutlinedButton.icon(
          onPressed: onToggleActive,
          icon: CenteredFaIcon(
            habit.isActive ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
            size: 13,
          ),
          label: Text(habit.isActive ? 'Pause' : 'Resume'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onEdit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.habit,
            foregroundColor: Colors.white,
          ),
          icon: const CenteredFaIcon(FontAwesomeIcons.pen, size: 13),
          label: const Text('Edit habit'),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          onSelected: (value) async {
            if (value == 'delete') await onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text(
                    'Delete habit',
                    style: TextStyle(color: AppColors.danger),
                  ),
                ],
              ),
            ),
          ],
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              border: Border.all(color: neutral.divider),
              borderRadius: BorderRadius.circular(10),
              color: neutral.card,
            ),
            child: const Icon(Icons.more_horiz_rounded),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.22)),
      ),
      child: Text(
        active ? 'Active' : 'Paused',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DesktopKpiGrid extends StatelessWidget {
  const _DesktopKpiGrid({required this.habit, required this.monthly});

  final Habit habit;
  final _MonthStats monthly;

  @override
  Widget build(BuildContext context) {
    final total = monthly.completed + monthly.skipped + monthly.missed;
    final monthRate = total == 0 ? 0 : ((monthly.completed / total) * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DesktopKpiCard(
              width: width,
              label: 'Current streak',
              value: '${habit.currentStreak}',
              suffix: 'days',
              icon: FontAwesomeIcons.fireFlameSimple,
              accent: habit.color,
            ),
            _DesktopKpiCard(
              width: width,
              label: 'Best streak',
              value: '${habit.bestStreak}',
              suffix: 'days',
              icon: FontAwesomeIcons.trophy,
              accent: Colors.amber.shade700,
            ),
            _DesktopKpiCard(
              width: width,
              label: '30-day completion',
              value: '${(habit.completionRate() * 100).round()}',
              suffix: '%',
              icon: FontAwesomeIcons.chartLine,
              accent: Colors.blue,
            ),
            _DesktopKpiCard(
              width: width,
              label: 'This month',
              value: '$monthRate',
              suffix: '%',
              icon: FontAwesomeIcons.calendarCheck,
              accent: Colors.green,
            ),
          ],
        );
      },
    );
  }
}

class _DesktopKpiCard extends StatelessWidget {
  const _DesktopKpiCard({
    required this.width,
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.accent,
  });

  final double width;
  final String label;
  final String value;
  final String suffix;
  final FaIconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      width: width,
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CenteredFaIcon(icon, color: accent, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: value,
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: ' $suffix',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 12,
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

