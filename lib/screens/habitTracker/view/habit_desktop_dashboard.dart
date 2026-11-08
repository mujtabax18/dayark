import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import '../../../models/habit.dart';
import '../../navigation/widgets/desktop_navigation_scope.dart';
import '../controller/habit_tracker_controller.dart';
import '../shared/habit_icon_catalog.dart';
import 'HabitDetailScreen.dart';
import 'HabitHistoryScreen.dart';
import 'HabitsScreen.dart';

part 'parts/habit_desktop_dashboard_habit_desktop_section.dart';
part 'parts/habit_desktop_dashboard_habit_desktop_overview.dart';
part 'parts/habit_desktop_dashboard_desktop_habit_card.dart';
part 'parts/habit_desktop_dashboard_habit_sidebar_item.dart';

/// Desktop-only Habit Coach workspace.
///
/// It owns a second-level sidebar and a nested Navigator, so overview, history,
/// habit details and habit editing stay inside the right pane of the desktop
/// admin shell instead of replacing the main application layout.
class HabitDesktopDashboard extends ConsumerStatefulWidget {
  const HabitDesktopDashboard({super.key, this.initialHabitId});

  final int? initialHabitId;

  @override
  ConsumerState<HabitDesktopDashboard> createState() =>
      _HabitDesktopDashboardState();
}

