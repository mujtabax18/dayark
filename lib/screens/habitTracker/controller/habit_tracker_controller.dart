import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../models/habit.dart';
import '../../../models/habit_progress.dart';
import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/habitTrackerService.dart';
import '../shared/habit_icon_catalog.dart';

class HabitTrackerController extends StateNotifier<HabitTrackerState> {
  HabitTrackerController(this._databaseService)
      : super(HabitTrackerState.initial()) {
    _habitService = HabitTrackerService(_databaseService);
    refresh();
  }

  final DatabaseService _databaseService;
  late final HabitTrackerService _habitService;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final habits = await _habitService.getAllHabits();
      state = state.copyWith(habits: habits, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> addHabit({
    required String title,
    String? description,
    TimeOfDay? notificationTime,
    String category = 'Personal growth',
    String reason = '',
    String cue = '',
    String reward = '',
    String difficulty = 'medium',
    int targetValue = 1,
    String targetUnit = 'time',
    int deadlineHour = 23,
    int deadlineMinute = 59,
    List<int> repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    int colorValue = 4280391411,
    int? iconCode,
  }) async {
    if (title.trim().isEmpty) return;
    await _run(() async {
      await _habitService.createHabit(Habit(
        title: title.trim(),
        description:
            description?.trim().isEmpty == true ? null : description?.trim(),
        createdAt: DateTime.now(),
        notificationTime: notificationTime,
        category: category,
        reason: reason.trim(),
        cue: cue.trim(),
        reward: reward.trim(),
        difficulty: difficulty,
        targetValue: targetValue,
        targetUnit: targetUnit,
        deadlineHour: deadlineHour,
        deadlineMinute: deadlineMinute,
        repeatDays: repeatDays,
        colorValue: colorValue,
        iconCode: iconCode ?? HabitIconCatalog.defaultIconCode,
      ));
    });
  }

  Future<void> updateHabit(Habit habit) =>
      _run(() => _habitService.updateHabit(habit));

  Future<void> editHabit({
    required int habitId,
    required String title,
    String? description,
    TimeOfDay? notificationTime,
    required String category,
    required String reason,
    required String cue,
    required String reward,
    required String difficulty,
    required int deadlineHour,
    required int deadlineMinute,
    required List<int> repeatDays,
    required int iconCode,
  }) async {
    if (title.trim().isEmpty || repeatDays.isEmpty) return;
    await _run(() => _habitService.updateHabitDetails(
          habitId: habitId,
          title: title,
          description: description,
          notificationTime: notificationTime == null
              ? null
              : '${notificationTime.hour.toString().padLeft(2, '0')}:${notificationTime.minute.toString().padLeft(2, '0')}',
          category: category,
          reason: reason,
          cue: cue,
          reward: reward,
          difficulty: difficulty,
          deadlineHour: deadlineHour,
          deadlineMinute: deadlineMinute,
          repeatDays: repeatDays,
          iconCode: iconCode,
        ));
  }

  Future<void> toggleHabitActive(int habitId, bool isActive) async {
    final habit = state.habits.firstWhere((item) => item.id == habitId);
    await updateHabit(habit.copyWith(isActive: isActive));
  }

  Future<void> deleteHabit(int habitId) =>
      _run(() => _habitService.deleteHabit(habitId));

  Future<bool> recordToday({
    required int habitId,
    required bool isCompleted,
    String? notes,
    double value = 1,
    String mood = 'neutral',
  }) async {
    final habit = state.habits.firstWhere((item) => item.id == habitId);
    final now = DateTime.now();
    if (!habit.canUpdate(now, now: now)) return false;
    await _run(() => _habitService.recordProgress(HabitProgress(
          habitId: habitId,
          date: now,
          isCompleted: isCompleted,
          notes: notes,
          value: value,
          mood: mood,
          status: isCompleted ? 'completed' : 'skipped',
          updatedAt: now,
        )));
    return true;
  }

  Future<bool> recordProgress({
    required int habitId,
    required DateTime date,
    required bool isCompleted,
    String? notes,
  }) async {
    final habit = state.habits.firstWhere((item) => item.id == habitId);
    if (!habit.canUpdate(date)) return false;
    await _run(() => _habitService.recordProgress(HabitProgress(
          habitId: habitId,
          date: date,
          isCompleted: isCompleted,
          notes: notes,
          status: isCompleted ? 'completed' : 'skipped',
          updatedAt: DateTime.now(),
        )));
    return true;
  }

  Future<void> clearProgress(int habitId, DateTime date) =>
      _run(() => _habitService.removeProgress(habitId, date));

  Future<void> undoToday(int habitId) => clearProgress(habitId, DateTime.now());

  Future<void> _run(Future<dynamic> Function() operation) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await operation();
      await refresh();
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}

class HabitTrackerState {
  const HabitTrackerState({
    required this.habits,
    required this.isLoading,
    this.error,
  });

  final List<Habit> habits;
  final bool isLoading;
  final String? error;

  factory HabitTrackerState.initial() => const HabitTrackerState(
        habits: [],
        isLoading: false,
      );

  List<Habit> get activeHabits =>
      habits.where((habit) => habit.isActive).toList();

  int get dueToday => activeHabits.where((habit) {
        final now = DateTime.now();
        return habit.isScheduledOn(now) && habit.progressFor(now) == null;
      }).length;

  int get completedToday => activeHabits
      .where((habit) => habit.progressFor(DateTime.now())?.isCompleted == true)
      .length;

  double get todayRate {
    final scheduled = activeHabits
        .where((habit) => habit.isScheduledOn(DateTime.now()))
        .length;
    return scheduled == 0 ? 0 : completedToday / scheduled;
  }

  HabitTrackerState copyWith({
    List<Habit>? habits,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      HabitTrackerState(
        habits: habits ?? this.habits,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

final habitTrackerControllerProvider =
    StateNotifierProvider<HabitTrackerController, HabitTrackerState>(
  (ref) => HabitTrackerController(DatabaseService()),
);

final habitTrackerServiceProvider = Provider<HabitTrackerService>(
  (ref) => HabitTrackerService(DatabaseService()),
);
