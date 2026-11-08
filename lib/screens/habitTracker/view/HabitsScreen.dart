import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/design/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/habit.dart';
import '../controller/habit_tracker_controller.dart';
import '../shared/habit_icon_catalog.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import 'HabitHistoryScreen.dart';

part 'parts/habits_screen_dashboard_header.dart';
part 'parts/habits_screen_habit_form_state.dart';

Future<void> showCreateHabitSheet(
  BuildContext context,
  WidgetRef ref,
) {
  final controller = ref.read(habitTrackerControllerProvider.notifier);
  return _showHabitForm(
    context,
    _HabitForm(controller: controller),
  );
}

Future<void> showEditHabitSheet(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
) {
  final controller = ref.read(habitTrackerControllerProvider.notifier);
  return _showHabitForm(
    context,
    _HabitForm(controller: controller, habit: habit),
  );
}

Future<void> _showHabitForm(BuildContext context, Widget form) {
  if (MediaQuery.sizeOf(context).width >= 900) {
    final height = MediaQuery.sizeOf(context).height * .82;
    return showDialog<void>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 760,
          height: height.clamp(560.0, 820.0).toDouble(),
          child: form,
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => form,
  );
}

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neutral = context.themeColors.neutral;
    final state = ref.watch(habitTrackerControllerProvider);
    final controller = ref.read(habitTrackerControllerProvider.notifier);

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: AppBar(
        backgroundColor: neutral.background,
        elevation: 0,
        title: Text('Habit Coach',
            style: TextStyle(
                color: neutral.textPrimary, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'History & calendar',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HabitHistoryScreen(),
              ),
            ),
            icon: const CenteredFaIcon(FontAwesomeIcons.calendarDays),
          ),
          IconButton(
              onPressed: controller.refresh,
              icon: const CenteredFaIcon(FontAwesomeIcons.repeat)),
          IconButton(
              onPressed: () => showCreateHabitSheet(context, ref),
              icon: const CenteredFaIcon(FontAwesomeIcons.plus)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.habit,
        foregroundColor: Colors.white,
        onPressed: () => showCreateHabitSheet(context, ref),
        icon: const CenteredFaIcon(FontAwesomeIcons.clipboardList),
        label: const Text('New habit'),
      ),
      body: ResponsivePageFrame(
        maxWidth: 1280,
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: state.isLoading && state.habits.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  _DashboardHeader(state: state),
                  const SizedBox(height: 16),
                  if (state.error != null)
                    _InfoBanner(
                        icon: FontAwesomeIcons.triangleExclamation,
                        text: state.error!,
                        color: AppColors.danger),
                  if (state.dueToday > 0)
                    _InfoBanner(
                      icon: FontAwesomeIcons.bell,
                      text:
                          '${state.dueToday} habit${state.dueToday == 1 ? '' : 's'} still need an update today. Updates close at each habit’s deadline.',
                      color: Colors.orange,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: Text('Today',
                              style: TextStyle(
                                  color: neutral.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700))),
                      Text(
                          '${state.completedToday}/${state.activeHabits.where((h) => h.isScheduledOn(DateTime.now())).length}',
                          style: TextStyle(
                              color: neutral.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state.activeHabits.isEmpty)
                    _EmptyState(
                        onAdd: () => showCreateHabitSheet(context, ref))
                  else
                    ...state.activeHabits.map((habit) => _HabitCard(
                          habit: habit,
                          onOpen: () => context.push('/habits/${habit.id}'),
                          onEdit: () => showEditHabitSheet(context, ref, habit),
                          onComplete: () => controller.recordToday(
                              habitId: habit.id!, isCompleted: true),
                          onSkip: () => controller.recordToday(
                              habitId: habit.id!, isCompleted: false),
                          onUndo: () => controller.undoToday(habit.id!),
                        )),
                  if (state.habits.any((habit) => !habit.isActive)) ...[
                    const SizedBox(height: 20),
                    Text('Paused habits',
                        style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...state.habits
                        .where((habit) => !habit.isActive)
                        .map((habit) => ListTile(
                              tileColor: neutral.card,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: neutral.divider)),
                              leading: CenteredFaIcon(
                                  HabitIconCatalog.fromCode(habit.iconCode,
                                      category: habit.category,
                                      title: habit.title),
                                  color: habit.color),
                              title: Text(habit.title),
                              subtitle: const Text('Paused'),
                              trailing: TextButton(
                                  onPressed: () => controller.toggleHabitActive(
                                      habit.id!, true),
                                  child: const Text('Resume')),
                              onTap: () => context.push('/habits/${habit.id}'),
                            )),
                  ],
                ],
              ),
        ),
      ),
    );
  }

}

