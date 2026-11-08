part of '../habit_desktop_dashboard.dart';

class _HabitDesktopOverview extends ConsumerWidget {
  const _HabitDesktopOverview({
    required this.section,
    required this.onOpenHabit,
    required this.onEditHabit,
    required this.onAddHabit,
    required this.onOpenHistory,
  });

  final _HabitDesktopSection section;
  final ValueChanged<int> onOpenHabit;
  final ValueChanged<Habit> onEditHabit;
  final VoidCallback onAddHabit;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitTrackerControllerProvider);
    final controller = ref.read(habitTrackerControllerProvider.notifier);
    final neutral = context.themeColors.neutral;
    final habits = switch (section) {
      _HabitDesktopSection.active => state.activeHabits,
      _HabitDesktopSection.paused =>
        state.habits.where((habit) => !habit.isActive).toList(),
      _ => state.habits,
    };
    final title = switch (section) {
      _HabitDesktopSection.active => 'Active habits',
      _HabitDesktopSection.paused => 'Paused habits',
      _ => 'Habit overview',
    };
    final subtitle = switch (section) {
      _HabitDesktopSection.active =>
        'Manage the habits that are currently part of your routine.',
      _HabitDesktopSection.paused =>
        'Review paused habits and resume them whenever you are ready.',
      _ => 'Track today, review consistency, and open any habit from one workspace.',
    };

    if (state.isLoading && state.habits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ColoredBox(
      color: neutral.background,
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: neutral.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onOpenHistory,
                  icon: const CenteredFaIcon(
                    FontAwesomeIcons.calendarDays,
                    size: 14,
                  ),
                  label: const Text('History'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onAddHabit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.habit,
                    foregroundColor: Colors.white,
                  ),
                  icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 14),
                  label: const Text('New habit'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (section == _HabitDesktopSection.overview) ...[
              _DesktopSummary(state: state),
              const SizedBox(height: 18),
            ],
            if (state.error != null) ...[
              _DesktopInfoBanner(
                text: state.error!,
                color: AppColors.danger,
                icon: FontAwesomeIcons.triangleExclamation,
              ),
              const SizedBox(height: 12),
            ],
            if (section == _HabitDesktopSection.overview && state.dueToday > 0) ...[
              _DesktopInfoBanner(
                text:
                    '${state.dueToday} habit${state.dueToday == 1 ? '' : 's'} still need an update today.',
                color: Colors.orange,
                icon: FontAwesomeIcons.bell,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Text(
                    section == _HabitDesktopSection.overview
                        ? 'All habits'
                        : title,
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${habits.length} total',
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (habits.isEmpty)
              _DesktopEmptyState(
                paused: section == _HabitDesktopSection.paused,
                onAdd: onAddHabit,
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 980 ? 2 : 1;
                  if (columns == 1) {
                    return Column(
                      children: habits
                          .map(
                            (habit) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DesktopHabitCard(
                                habit: habit,
                                onOpen: () => onOpenHabit(habit.id!),
                                onEdit: () => onEditHabit(habit),
                                onComplete: () => controller.recordToday(
                                  habitId: habit.id!,
                                  isCompleted: true,
                                ),
                                onSkip: () => controller.recordToday(
                                  habitId: habit.id!,
                                  isCompleted: false,
                                ),
                                onUndo: () => controller.undoToday(habit.id!),
                                onToggleActive: () => controller.toggleHabitActive(
                                  habit.id!,
                                  !habit.isActive,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }

                  final rows = <Widget>[];
                  for (var i = 0; i < habits.length; i += 2) {
                    rows.add(
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _DesktopHabitCard(
                                habit: habits[i],
                                onOpen: () => onOpenHabit(habits[i].id!),
                                onEdit: () => onEditHabit(habits[i]),
                                onComplete: () => controller.recordToday(
                                  habitId: habits[i].id!,
                                  isCompleted: true,
                                ),
                                onSkip: () => controller.recordToday(
                                  habitId: habits[i].id!,
                                  isCompleted: false,
                                ),
                                onUndo: () => controller.undoToday(habits[i].id!),
                                onToggleActive: () => controller.toggleHabitActive(
                                  habits[i].id!,
                                  !habits[i].isActive,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: i + 1 < habits.length
                                  ? _DesktopHabitCard(
                                      habit: habits[i + 1],
                                      onOpen: () =>
                                          onOpenHabit(habits[i + 1].id!),
                                      onEdit: () => onEditHabit(habits[i + 1]),
                                      onComplete: () => controller.recordToday(
                                        habitId: habits[i + 1].id!,
                                        isCompleted: true,
                                      ),
                                      onSkip: () => controller.recordToday(
                                        habitId: habits[i + 1].id!,
                                        isCompleted: false,
                                      ),
                                      onUndo: () => controller
                                          .undoToday(habits[i + 1].id!),
                                      onToggleActive: () =>
                                          controller.toggleHabitActive(
                                        habits[i + 1].id!,
                                        !habits[i + 1].isActive,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return Column(children: rows);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _DesktopSummary extends StatelessWidget {
  const _DesktopSummary({required this.state});
  final HabitTrackerState state;

  @override
  Widget build(BuildContext context) {
    final best = state.habits.fold<int>(
      0,
      (current, habit) =>
          habit.currentStreak > current ? habit.currentStreak : current,
    );
    final scheduledToday = state.activeHabits
        .where((habit) => habit.isScheduledOn(DateTime.now()))
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final cards = [
          _SummaryCard(
            icon: FontAwesomeIcons.chartPie,
            label: 'Today rate',
            value: '${(state.todayRate * 100).round()}%',
            helper: '$scheduledToday scheduled',
          ),
          _SummaryCard(
            icon: FontAwesomeIcons.check,
            label: 'Completed today',
            value: '${state.completedToday}',
            helper: 'Updates recorded',
          ),
          _SummaryCard(
            icon: FontAwesomeIcons.clock,
            label: 'Still due',
            value: '${state.dueToday}',
            helper: 'Before deadlines',
          ),
          _SummaryCard(
            icon: FontAwesomeIcons.fireFlameSimple,
            label: 'Best streak',
            value: '$best',
            helper: 'Consecutive days',
          ),
        ];

        if (compact) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: (constraints.maxWidth - 10) / 2,
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });

  final FaIconData icon;
  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.habit.withOpacity(.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CenteredFaIcon(icon, color: AppColors.habit, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  helper,
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 9,
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

