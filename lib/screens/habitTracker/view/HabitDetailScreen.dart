import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import '../../../models/habit.dart';
import '../../../models/habit_progress.dart';
import '../controller/habit_tracker_controller.dart';
import '../shared/habit_icon_catalog.dart';
import 'HabitCalendar.dart';
import 'HabitsScreen.dart';

part 'parts/habit_detail_screen_desktop_habit_detail.dart';
part 'parts/habit_detail_screen_desktop_panel.dart';
part 'parts/habit_detail_screen_desktop_plan_item.dart';

class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final int habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final state = ref.watch(habitTrackerControllerProvider);
    final controller = ref.read(habitTrackerControllerProvider.notifier);

    Habit? habit;
    for (final item in state.habits) {
      if (item.id == habitId) habit = item;
    }

    if (habit == null) {
      return Scaffold(
        backgroundColor: neutral.background,
        body: const Center(child: Text('Habit not found')),
      );
    }

    final selectedHabit = habit;
    final monthly = _monthStats(selectedHabit, DateTime.now());
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    Future<void> editHabit() =>
        showEditHabitSheet(context, ref, selectedHabit);

    Future<void> toggleActive() => controller.toggleHabitActive(
          selectedHabit.id!,
          !selectedHabit.isActive,
        );

    Future<void> deleteHabit() async {
      final confirmed = await _confirmDelete(context, selectedHabit);
      if (!confirmed) return;
      await controller.deleteHabit(selectedHabit.id!);
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }

    if (isDesktop) {
      return Scaffold(
        backgroundColor: neutral.background,
        body: _DesktopHabitDetail(
          habit: selectedHabit,
          monthly: monthly,
          controller: controller,
          onEdit: editHabit,
          onToggleActive: toggleActive,
          onDelete: deleteHabit,
          onEditDate: (date) => _editProgressForDate(
            context,
            controller,
            selectedHabit,
            date,
            desktop: true,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        title: Text(selectedHabit.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') await editHabit();
              if (value == 'pause') await toggleActive();
              if (value == 'delete') await deleteHabit();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit habit')),
              PopupMenuItem(
                value: 'pause',
                child: Text(
                  selectedHabit.isActive ? 'Pause habit' : 'Resume habit',
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete habit',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HeroCard(habit: selectedHabit),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Current streak',
                  value: '${selectedHabit.currentStreak}',
                  suffix: 'days',
                  icon: FontAwesomeIcons.fireFlameSimple,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Best streak',
                  value: '${selectedHabit.bestStreak}',
                  suffix: 'days',
                  icon: FontAwesomeIcons.trophy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: '30-day rate',
                  value: '${(selectedHabit.completionRate() * 100).round()}',
                  suffix: '%',
                  icon: FontAwesomeIcons.chartLine,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Monthly progress',
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      values: monthly.dailyRates,
                      lineColor: selectedHabit.color,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Legend(
                      color: selectedHabit.color,
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
            ),
          ),
          const SizedBox(height: 14),
          _Section(
            title: 'Calendar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap today or any past scheduled date to update its status.',
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                HabitCalendar(
                  habit: selectedHabit,
                  onDaySelected: (date) => _editProgressForDate(
                    context,
                    controller,
                    selectedHabit,
                    date,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_hasPlan(selectedHabit))
            _Section(
              title: 'Your behavior plan',
              child: Column(
                children: [
                  if (selectedHabit.reason.isNotEmpty)
                    _PlanRow(
                      icon: FontAwesomeIcons.flag,
                      label: 'Why',
                      value: selectedHabit.reason,
                    ),
                  if (selectedHabit.cue.isNotEmpty)
                    _PlanRow(
                      icon: FontAwesomeIcons.bolt,
                      label: 'Cue',
                      value: selectedHabit.cue,
                    ),
                  if (selectedHabit.reward.isNotEmpty)
                    _PlanRow(
                      icon: FontAwesomeIcons.gift,
                      label: 'Reward',
                      value: selectedHabit.reward,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          _Section(
            title: 'Coach insight',
            child: Text(
              _coachInsight(selectedHabit, monthly),
              style: TextStyle(color: neutral.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  static bool _hasPlan(Habit habit) =>
      habit.reason.isNotEmpty || habit.cue.isNotEmpty || habit.reward.isNotEmpty;

  static Future<bool> _confirmDelete(BuildContext context, Habit habit) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete habit?'),
            content: Text(
              'Delete “${habit.title}” and its recorded progress? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editProgressForDate(
    BuildContext context,
    HabitTrackerController controller,
    Habit habit,
    DateTime date, {
    bool desktop = false,
  }) async {
    if (!habit.canUpdate(date) && habit.progressFor(date) == null) return;

    final progress = habit.progressFor(date);
    final label = MaterialLocalizations.of(context).formatMediumDate(date);

    final action = desktop
        ? await showDialog<String>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text('Update $label'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress?.isCompleted == true
                          ? 'Currently marked completed.'
                          : progress?.isSkipped == true
                              ? 'Currently marked skipped.'
                              : 'No update has been recorded for this date.',
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                Navigator.pop(dialogContext, 'completed'),
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Completed'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                Navigator.pop(dialogContext, 'skipped'),
                            icon: const Icon(Icons.remove_circle_outline),
                            label: const Text('Skipped'),
                          ),
                        ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () =>
                              Navigator.pop(dialogContext, 'clear'),
                          icon: const Icon(Icons.undo),
                          label: const Text('Clear this date'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          )
        : await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress?.isCompleted == true
                          ? 'Currently marked completed.'
                          : progress?.isSkipped == true
                              ? 'Currently marked skipped.'
                              : 'No update has been recorded for this date.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.pop(sheetContext, 'completed'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark completed'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'skipped'),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Mark skipped'),
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, 'clear'),
                        icon: const Icon(Icons.undo),
                        label: const Text('Clear this date'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );

    if (action == null) return;
    if (action == 'clear') {
      await controller.clearProgress(habit.id!, date);
      return;
    }
    await controller.recordProgress(
      habitId: habit.id!,
      date: date,
      isCompleted: action == 'completed',
    );
  }

  static _MonthStats _monthStats(Habit habit, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    var completed = 0;
    var skipped = 0;
    var missed = 0;
    final values = <double>[];
    final today = DateTime.now();
    for (var day = 1; day <= lastDay; day++) {
      final date = DateTime(month.year, month.month, day);
      if (!habit.isScheduledOn(date) ||
          date.isBefore(
            DateTime(
              habit.createdAt.year,
              habit.createdAt.month,
              habit.createdAt.day,
            ),
          ) ||
          date.isAfter(today)) {
        values.add(0);
        continue;
      }
      final progress = habit.progressFor(date);
      if (progress?.isCompleted == true) {
        completed++;
      } else if (progress?.isSkipped == true) {
        skipped++;
      } else if (date.isBefore(DateTime(today.year, today.month, today.day))) {
        missed++;
      }
      values.add(progress?.isCompleted == true ? 1 : 0);
    }
    return _MonthStats(
      completed: completed,
      skipped: skipped,
      missed: missed,
      dailyRates: values,
    );
  }

  static String _coachInsight(Habit habit, _MonthStats stats) {
    final total = stats.completed + stats.skipped + stats.missed;
    if (total == 0) {
      return 'You are at the beginning. Make the first version of this habit so small that it is difficult to avoid.';
    }
    final rate = stats.completed / total;
    if (rate >= .85) {
      return 'Your consistency is strong. Protect the cue and avoid increasing difficulty too quickly. Stable repetition matters more than intensity.';
    }
    if (habit.currentStreak == 0) {
      return 'Restart today with the minimum version of the habit. A missed day is data, not failure. Focus on making the cue obvious and the action easier.';
    }
    return 'You are building momentum. The biggest improvement now is reducing friction before the habit starts and completing it earlier than the deadline.';
  }
}

