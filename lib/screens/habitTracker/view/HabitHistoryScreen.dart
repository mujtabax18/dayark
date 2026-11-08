import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import '../../../models/habit.dart';
import '../controller/habit_tracker_controller.dart';
import '../shared/habit_icon_catalog.dart';

part 'parts/habit_history_screen_state.dart';
part 'parts/habit_history_screen_history_habit_row.dart';
part 'parts/habit_history_screen_collective_month_stats.dart';

/// Collective habit history for both phone and desktop.
///
/// The calendar summarizes every habit scheduled on each date. Selecting a
/// date exposes every scheduled habit for that day and lets the user correct
/// the status without opening habits one by one.
class HabitHistoryScreen extends ConsumerStatefulWidget {
  const HabitHistoryScreen({super.key});

  @override
  ConsumerState<HabitHistoryScreen> createState() =>
      _HabitHistoryScreenState();
}

