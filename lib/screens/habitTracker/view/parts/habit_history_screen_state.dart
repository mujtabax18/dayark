part of '../HabitHistoryScreen.dart';

class _HabitHistoryScreenState extends ConsumerState<HabitHistoryScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final today = _dayOnly(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final state = ref.watch(habitTrackerControllerProvider);
    final controller = ref.read(habitTrackerControllerProvider.notifier);
    final habits = state.habits;
    final monthStats = _monthStats(habits, _focusedDay);
    final selectedStats = _dayStats(habits, _selectedDay);
    final selectedHabits = habits
        .where((habit) => _isHabitRelevantOn(habit, _selectedDay))
        .toList(growable: false);

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        title: const Text('Habit history'),
        actions: [
          IconButton(
            tooltip: 'Today',
            onPressed: () {
              final today = _dayOnly(DateTime.now());
              setState(() {
                _focusedDay = today;
                _selectedDay = today;
              });
            },
            icon: const CenteredFaIcon(FontAwesomeIcons.calendarDay),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refresh,
            icon: const CenteredFaIcon(FontAwesomeIcons.repeat),
          ),
        ],
      ),
      body: state.isLoading && habits.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final desktopLayout = constraints.maxWidth >= 900;
                final calendarPanel = _HistoryCalendarPanel(
                  habits: habits,
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  stats: monthStats,
                  onFocusedDayChanged: (day) {
                    if (_sameMonth(day, _focusedDay)) return;
                    setState(() => _focusedDay = _dayOnly(day));
                  },
                  onPageChanged: (day) =>
                      setState(() => _focusedDay = _dayOnly(day)),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = _dayOnly(selected);
                      _focusedDay = _dayOnly(focused);
                    });
                  },
                );
                final detailsPanel = _SelectedDayPanel(
                  date: _selectedDay,
                  stats: selectedStats,
                  habits: selectedHabits,
                  onSetStatus: (habit, status) => _setStatus(
                    controller,
                    habit,
                    _selectedDay,
                    status,
                  ),
                );

                if (desktopLayout) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(child: calendarPanel),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(child: detailsPanel),
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
                  children: [
                    calendarPanel,
                    const SizedBox(height: 14),
                    detailsPanel,
                  ],
                );
              },
            ),
    );
  }

  Future<void> _setStatus(
    HabitTrackerController controller,
    Habit habit,
    DateTime date,
    _HistoryAction action,
  ) async {
    final existing = habit.progressFor(date);

    if (!habit.canUpdate(date)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This date can no longer be changed for this habit.',
          ),
        ),
      );
      return;
    }

    if (action == _HistoryAction.clear) {
      if (existing == null) return;
      await controller.clearProgress(habit.id!, date);
      return;
    }

    await controller.recordProgress(
      habitId: habit.id!,
      date: date,
      isCompleted: action == _HistoryAction.completed,
      notes: existing?.notes,
    );
  }
}

class _HistoryCalendarPanel extends StatelessWidget {
  const _HistoryCalendarPanel({
    required this.habits,
    required this.focusedDay,
    required this.selectedDay,
    required this.stats,
    required this.onFocusedDayChanged,
    required this.onPageChanged,
    required this.onDaySelected,
  });

  final List<Habit> habits;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final _CollectiveMonthStats stats;
  final ValueChanged<DateTime> onFocusedDayChanged;
  final ValueChanged<DateTime> onPageChanged;
  final void Function(DateTime selected, DateTime focused) onDaySelected;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final firstDay = _firstHabitDay(habits);
    final lastDay = _dayOnly(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neutral.divider),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collective calendar',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Every scheduled habit in one calendar.',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _RateBadge(rate: stats.rate),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MonthStatChip(
                icon: FontAwesomeIcons.check,
                label: 'Completed',
                value: stats.completed,
                color: AppColors.habit,
              ),
              _MonthStatChip(
                icon: FontAwesomeIcons.minus,
                label: 'Skipped',
                value: stats.skipped,
                color: Colors.orange,
              ),
              _MonthStatChip(
                icon: FontAwesomeIcons.xmark,
                label: 'Missed',
                value: stats.missed,
                color: AppColors.danger,
              ),
              _MonthStatChip(
                icon: FontAwesomeIcons.listCheck,
                label: 'Scheduled',
                value: stats.scheduled,
                color: neutral.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TableCalendar<void>(
            firstDay: firstDay,
            lastDay: lastDay,
            focusedDay: focusedDay.isBefore(firstDay)
                ? firstDay
                : focusedDay.isAfter(lastDay)
                    ? lastDay
                    : focusedDay,
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.horizontalSwipe,
            selectedDayPredicate: (day) => _sameDay(day, selectedDay),
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            onHeaderTapped: onFocusedDayChanged,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: neutral.textPrimary,
                fontWeight: FontWeight.w800,
              ),
              leftChevronIcon: CenteredFaIcon(
                FontAwesomeIcons.angleLeft,
                color: neutral.textSecondary,
              ),
              rightChevronIcon: CenteredFaIcon(
                FontAwesomeIcons.angleRight,
                color: neutral.textSecondary,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: neutral.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              weekendStyle: TextStyle(
                color: neutral.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              isTodayHighlighted: false,
            ),
            calendarBuilders: CalendarBuilders<void>(
              defaultBuilder: (context, day, _) => _CollectiveDayCell(
                day: day,
                stats: _dayStats(habits, day),
              ),
              todayBuilder: (context, day, _) => _CollectiveDayCell(
                day: day,
                stats: _dayStats(habits, day),
                isToday: true,
              ),
              selectedBuilder: (context, day, _) => _CollectiveDayCell(
                day: day,
                stats: _dayStats(habits, day),
                selected: true,
                isToday: _sameDay(day, DateTime.now()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: const [
              _CalendarLegend(color: AppColors.habit, label: 'Completed'),
              _CalendarLegend(color: Colors.orange, label: 'Skipped'),
              _CalendarLegend(color: AppColors.danger, label: 'Missed'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectedDayPanel extends StatelessWidget {
  const _SelectedDayPanel({
    required this.date,
    required this.stats,
    required this.habits,
    required this.onSetStatus,
  });

  final DateTime date;
  final _CollectiveDayStats stats;
  final List<Habit> habits;
  final void Function(Habit habit, _HistoryAction action) onSetStatus;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final title = MaterialLocalizations.of(context).formatFullDate(date);

    return Container(
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  stats.scheduled == 0
                      ? 'No habits were scheduled for this date.'
                      : '${stats.completed} of ${stats.scheduled} completed · ${stats.skipped} skipped · ${stats.missed} missed',
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: neutral.divider),
          if (habits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(28),
              child: Center(
                child: Column(
                  children: [
                    CenteredFaIcon(
                      FontAwesomeIcons.calendarCheck,
                      size: 40,
                      color: neutral.textDisabled,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Nothing scheduled',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: habits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final habit = habits[index];
                return _HistoryHabitRow(
                  habit: habit,
                  date: date,
                  onSetStatus: (action) => onSetStatus(habit, action),
                );
              },
            ),
        ],
      ),
    );
  }
}

