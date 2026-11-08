import 'package:flutter/material.dart';

import 'habit_progress.dart';

class Habit {
  final int? id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final TimeOfDay? notificationTime;
  final bool isActive;
  final String category;
  final String reason;
  final String cue;
  final String reward;
  final String difficulty;
  final int colorValue;
  final int iconCode;
  final int targetValue;
  final String targetUnit;
  final int deadlineHour;
  final int deadlineMinute;
  final int graceMinutes;
  final List<int> repeatDays;
  final DateTime? archivedAt;
  final List<HabitProgress> progressList;

  const Habit({
    this.id,
    required this.title,
    this.description,
    required this.createdAt,
    this.notificationTime,
    this.isActive = true,
    this.category = 'Personal growth',
    this.reason = '',
    this.cue = '',
    this.reward = '',
    this.difficulty = 'medium',
    this.colorValue = 4280391411,
    this.iconCode = 0xe87d,
    this.targetValue = 1,
    this.targetUnit = 'time',
    this.deadlineHour = 23,
    this.deadlineMinute = 59,
    this.graceMinutes = 0,
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.archivedAt,
    this.progressList = const [],
  });

  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  bool isScheduledOn(DateTime date) => repeatDays.contains(date.weekday);

  DateTime deadlineFor(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day,
        deadlineHour,
        deadlineMinute,
      ).add(Duration(minutes: graceMinutes));

  HabitProgress? progressFor(DateTime date) {
    for (final progress in progressList) {
      if (_sameDay(progress.date, date)) return progress;
    }
    return null;
  }

  bool canUpdate(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final selectedDay = DateTime(date.year, date.month, date.day);
    final today = DateTime(current.year, current.month, current.day);
    final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (selectedDay.isBefore(createdDay) || selectedDay.isAfter(today)) {
      return false;
    }
    if (!isScheduledOn(selectedDay)) return false;

    // Past scheduled dates remain editable so users can correct or backfill
    // their history. The deadline is only enforced for today's update.
    if (selectedDay.isBefore(today)) return true;
    return current.isBefore(
      deadlineFor(selectedDay).add(const Duration(minutes: 1)),
    );
  }

  int get currentStreak {
    var day = DateTime.now();
    if (!isScheduledOn(day) || progressFor(day)?.isCompleted != true) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    final oldest = DateTime(createdAt.year, createdAt.month, createdAt.day);
    while (!day.isBefore(oldest)) {
      if (!isScheduledOn(day)) {
        day = day.subtract(const Duration(days: 1));
        continue;
      }
      if (progressFor(day)?.isCompleted == true) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  int get bestStreak {
    final completed = progressList
        .where((e) => e.isCompleted)
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .toList()
      ..sort();
    var best = 0;
    var current = 0;
    DateTime? previous;
    for (final date in completed) {
      if (previous == null) {
        current = 1;
      } else {
        var cursor = previous.add(const Duration(days: 1));
        while (!isScheduledOn(cursor) && cursor.isBefore(date)) {
          cursor = cursor.add(const Duration(days: 1));
        }
        current = _sameDay(cursor, date) ? current + 1 : 1;
      }
      if (current > best) best = current;
      previous = date;
    }
    return best;
  }

  double completionRate({int days = 30}) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days - 1));
    var expected = 0;
    var completed = 0;
    for (var i = 0; i < days; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      if (day.isBefore(DateTime(createdAt.year, createdAt.month, createdAt.day)) ||
          !isScheduledOn(day)) continue;
      expected++;
      if (progressFor(day)?.isCompleted == true) completed++;
    }
    return expected == 0 ? 0 : completed / expected;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'created_at': createdAt.toIso8601String(),
        'notification_time': notificationTime == null
            ? null
            : '${notificationTime!.hour.toString().padLeft(2, '0')}:'
                '${notificationTime!.minute.toString().padLeft(2, '0')}',
        'is_active': isActive ? 1 : 0,
        'category': category,
        'reason': reason,
        'cue': cue,
        'reward': reward,
        'difficulty': difficulty,
        'color_value': colorValue,
        'icon_code': iconCode,
        'target_value': targetValue,
        'target_unit': targetUnit,
        'deadline_hour': deadlineHour,
        'deadline_minute': deadlineMinute,
        'grace_minutes': graceMinutes,
        'repeat_days': repeatDays.join(','),
        'archived_at': archivedAt?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory Habit.fromMap(
    Map<String, dynamic> map, {
    List<HabitProgress> progressList = const [],
  }) {
    final reminder = map['notification_time']?.toString().split(':');
    final days = map['repeat_days']?.toString().split(',') ?? const [];
    return Habit(
      id: map['id'] as int?,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      notificationTime: reminder != null && reminder.length == 2
          ? TimeOfDay(
              hour: int.tryParse(reminder[0]) ?? 9,
              minute: int.tryParse(reminder[1]) ?? 0,
            )
          : null,
      isActive: (map['is_active'] as num? ?? 1).toInt() == 1,
      category: map['category']?.toString() ?? 'Personal growth',
      reason: map['reason']?.toString() ?? '',
      cue: map['cue']?.toString() ?? '',
      reward: map['reward']?.toString() ?? '',
      difficulty: map['difficulty']?.toString() ?? 'medium',
      colorValue: (map['color_value'] as num? ?? 4280391411).toInt(),
      iconCode: (map['icon_code'] as num? ?? 0xe87d).toInt(),
      targetValue: (map['target_value'] as num? ?? 1).toInt(),
      targetUnit: map['target_unit']?.toString() ?? 'time',
      deadlineHour: (map['deadline_hour'] as num? ?? 23).toInt(),
      deadlineMinute: (map['deadline_minute'] as num? ?? 59).toInt(),
      graceMinutes: (map['grace_minutes'] as num? ?? 0).toInt(),
      repeatDays: days.map(int.tryParse).whereType<int>().toList().isEmpty
          ? const [1, 2, 3, 4, 5, 6, 7]
          : days.map(int.tryParse).whereType<int>().toList(),
      archivedAt: map['archived_at'] == null
          ? null
          : DateTime.tryParse(map['archived_at'].toString()),
      progressList: progressList,
    );
  }

  Habit copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? createdAt,
    TimeOfDay? notificationTime,
    bool clearNotification = false,
    bool? isActive,
    String? category,
    String? reason,
    String? cue,
    String? reward,
    String? difficulty,
    int? colorValue,
    int? iconCode,
    int? targetValue,
    String? targetUnit,
    int? deadlineHour,
    int? deadlineMinute,
    int? graceMinutes,
    List<int>? repeatDays,
    DateTime? archivedAt,
    List<HabitProgress>? progressList,
  }) =>
      Habit(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        notificationTime:
            clearNotification ? null : notificationTime ?? this.notificationTime,
        isActive: isActive ?? this.isActive,
        category: category ?? this.category,
        reason: reason ?? this.reason,
        cue: cue ?? this.cue,
        reward: reward ?? this.reward,
        difficulty: difficulty ?? this.difficulty,
        colorValue: colorValue ?? this.colorValue,
        iconCode: iconCode ?? this.iconCode,
        targetValue: targetValue ?? this.targetValue,
        targetUnit: targetUnit ?? this.targetUnit,
        deadlineHour: deadlineHour ?? this.deadlineHour,
        deadlineMinute: deadlineMinute ?? this.deadlineMinute,
        graceMinutes: graceMinutes ?? this.graceMinutes,
        repeatDays: repeatDays ?? this.repeatDays,
        archivedAt: archivedAt ?? this.archivedAt,
        progressList: progressList ?? this.progressList,
      );

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
