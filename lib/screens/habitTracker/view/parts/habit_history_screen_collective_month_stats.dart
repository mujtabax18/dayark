part of '../HabitHistoryScreen.dart';

class _CollectiveMonthStats {
  const _CollectiveMonthStats({
    required this.scheduled,
    required this.completed,
    required this.skipped,
    required this.missed,
  });

  final int scheduled;
  final int completed;
  final int skipped;
  final int missed;

  double get rate => scheduled == 0 ? 0 : completed / scheduled;
}

_CollectiveDayStats _dayStats(List<Habit> habits, DateTime date) {
  final selected = _dayOnly(date);
  final today = _dayOnly(DateTime.now());
  var scheduled = 0;
  var completed = 0;
  var skipped = 0;
  var missed = 0;

  for (final habit in habits) {
    if (!_isHabitRelevantOn(habit, selected)) continue;
    scheduled++;
    final progress = habit.progressFor(selected);
    if (progress?.isCompleted == true) {
      completed++;
    } else if (progress?.isSkipped == true) {
      skipped++;
    } else if (selected.isBefore(today)) {
      missed++;
    }
  }

  return _CollectiveDayStats(
    scheduled: scheduled,
    completed: completed,
    skipped: skipped,
    missed: missed,
  );
}

_CollectiveMonthStats _monthStats(List<Habit> habits, DateTime month) {
  final last = DateTime(month.year, month.month + 1, 0).day;
  var scheduled = 0;
  var completed = 0;
  var skipped = 0;
  var missed = 0;

  for (var day = 1; day <= last; day++) {
    final date = DateTime(month.year, month.month, day);
    final stats = _dayStats(habits, date);
    scheduled += stats.scheduled;
    completed += stats.completed;
    skipped += stats.skipped;
    missed += stats.missed;
  }

  return _CollectiveMonthStats(
    scheduled: scheduled,
    completed: completed,
    skipped: skipped,
    missed: missed,
  );
}

bool _isHabitRelevantOn(Habit habit, DateTime date) {
  final day = _dayOnly(date);
  final created = _dayOnly(habit.createdAt);
  if (day.isBefore(created) || day.isAfter(_dayOnly(DateTime.now()))) {
    return false;
  }
  if (habit.archivedAt != null && day.isAfter(_dayOnly(habit.archivedAt!))) {
    return false;
  }
  return habit.isScheduledOn(day);
}

DateTime _firstHabitDay(List<Habit> habits) {
  if (habits.isEmpty) {
    final now = DateTime.now();
    return DateTime(now.year - 1, now.month, 1);
  }
  var earliest = _dayOnly(habits.first.createdAt);
  for (final habit in habits.skip(1)) {
    final created = _dayOnly(habit.createdAt);
    if (created.isBefore(earliest)) earliest = created;
  }
  final today = _dayOnly(DateTime.now());
  return earliest.isAfter(today) ? today : earliest;
}

DateTime _dayOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;
