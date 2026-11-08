part of '../HabitsScreen.dart';

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.state});
  final HabitTrackerState state;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final best = state.habits.fold<int>(
        0,
        (value, habit) =>
            habit.currentStreak > value ? habit.currentStreak : value);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AppColors.habit, AppColors.habit.withOpacity(.72)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Today’s progress',
            style:
                TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                  value: state.todayRate,
                  strokeWidth: 8,
                  backgroundColor: Colors.white24,
                  color: Colors.white),
              Text('${(state.todayRate * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    state.todayRate == 1
                        ? 'Excellent. Today is complete.'
                        : 'Small actions build lasting change.',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Row(children: [
                  _MiniStat(label: 'Done', value: '${state.completedToday}'),
                  _MiniStat(label: 'Due', value: '${state.dueToday}'),
                  _MiniStat(label: 'Best streak', value: '$best'),
                ]),
              ])),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))
      ]));
}

class _HabitCard extends StatelessWidget {
  const _HabitCard(
      {required this.habit,
      required this.onOpen,
      required this.onEdit,
      required this.onComplete,
      required this.onSkip,
      required this.onUndo});
  final Habit habit;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final now = DateTime.now();
    final progress = habit.progressFor(now);
    final scheduled = habit.isScheduledOn(now);
    final expired = scheduled && !habit.canUpdate(now) && progress == null;
    final status = !scheduled
        ? 'Rest day'
        : progress?.isCompleted == true
            ? 'Completed'
            : progress?.isSkipped == true
                ? 'Skipped'
                : expired
                    ? 'Missed'
                    : 'Due by ${TimeOfDay(hour: habit.deadlineHour, minute: habit.deadlineMinute).format(context)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: neutral.divider)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: habit.color.withOpacity(.14),
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: CenteredFaIcon(
                          HabitIconCatalog.fromCode(habit.iconCode,
                              category: habit.category, title: habit.title),
                          color: habit.color))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(habit.title,
                        style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(status,
                        style: TextStyle(
                            color: expired
                                ? AppColors.danger
                                : neutral.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ])),
              IconButton(
                tooltip: 'Edit habit',
                onPressed: onEdit,
                icon: const CenteredFaIcon(FontAwesomeIcons.pen, size: 16),
              ),
              Column(children: [
                Text('🔥 ${habit.currentStreak}',
                    style: TextStyle(
                        color: neutral.textPrimary,
                        fontWeight: FontWeight.w700)),
                Text('${(habit.completionRate() * 100).round()}% / 30d',
                    style:
                        TextStyle(color: neutral.textSecondary, fontSize: 10))
              ]),
            ]),
            if (scheduled) ...[
              const SizedBox(height: 12),
              if (progress != null)
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                        onPressed: onUndo,
                        icon: const CenteredFaIcon(FontAwesomeIcons.clockRotateLeft),
                        label: const Text('Undo today’s update')))
              else if (!expired)
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: onSkip,
                          child: const Text('Skip honestly'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: habit.color),
                          onPressed: onComplete,
                          icon: const CenteredFaIcon(FontAwesomeIcons.check),
                          label: const Text('Complete'))),
                ]),
            ],
          ]),
        ),
      ),
    );
  }
}

class _HabitForm extends StatefulWidget {
  const _HabitForm({required this.controller, this.habit});
  final HabitTrackerController controller;
  final Habit? habit;
  @override
  State<_HabitForm> createState() => _HabitFormState();
}

