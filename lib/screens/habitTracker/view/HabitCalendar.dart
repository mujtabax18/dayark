import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/habit.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';

class HabitCalendar extends StatelessWidget {
  const HabitCalendar({
    super.key,
    required this.habit,
    this.onDaySelected,
  });

  final Habit habit;
  final ValueChanged<DateTime>? onDaySelected;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final now = DateTime.now();
    return TableCalendar(
      firstDay: DateTime(habit.createdAt.year, habit.createdAt.month, habit.createdAt.day),
      lastDay: DateTime(now.year + 1, 12, 31),
      focusedDay: now,
      calendarFormat: CalendarFormat.month,
      availableGestures: AvailableGestures.horizontalSwipe,
      enabledDayPredicate: (day) => habit.canUpdate(day),
      onDaySelected: onDaySelected == null
          ? null
          : (selectedDay, _) {
              if (habit.canUpdate(selectedDay)) {
                onDaySelected!(selectedDay);
              }
            },
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w700),
        leftChevronIcon: CenteredFaIcon(FontAwesomeIcons.angleLeft, color: neutral.textSecondary),
        rightChevronIcon: CenteredFaIcon(FontAwesomeIcons.angleRight, color: neutral.textSecondary),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: neutral.textSecondary, fontWeight: FontWeight.w600),
        weekendStyle: TextStyle(color: neutral.textSecondary, fontWeight: FontWeight.w600),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: habit.color, width: 2)),
        todayTextStyle: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w800),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, _) => _DayCell(habit: habit, day: day),
        todayBuilder: (context, day, _) => _DayCell(habit: habit, day: day, isToday: true),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.habit, required this.day, this.isToday = false});
  final Habit habit;
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final progress = habit.progressFor(day);
    final scheduled = habit.isScheduledOn(day);
    final today = DateTime.now();
    final isPast = DateTime(day.year, day.month, day.day).isBefore(DateTime(today.year, today.month, today.day));
    Color? background;
    FaIconData? marker;
    Color foreground = neutral.textPrimary;

    if (!scheduled) {
      foreground = neutral.textDisabled;
    } else if (progress?.isCompleted == true) {
      background = habit.color;
      foreground = Colors.white;
      marker = FontAwesomeIcons.check;
    } else if (progress?.isSkipped == true) {
      background = Colors.orange.withOpacity(.16);
      foreground = Colors.orange.shade800;
      marker = FontAwesomeIcons.minus;
    } else if (isPast) {
      background = AppColors.danger.withOpacity(.12);
      foreground = AppColors.danger;
      marker = FontAwesomeIcons.xmark;
    }

    return Center(
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: isToday ? Border.all(color: habit.color, width: 2) : null,
        ),
        child: Stack(alignment: Alignment.center, children: [
          Text('${day.day}', style: TextStyle(color: foreground, fontWeight: FontWeight.w700)),
          if (marker != null)
            Positioned(right: 1, bottom: 1, child: CenteredFaIcon(marker, size: 11, color: foreground)),
        ]),
      ),
    );
  }
}
