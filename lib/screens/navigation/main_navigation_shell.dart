import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_tokens.dart';
import '../../core/design/responsive_layout.dart';
import '../../localization/app_localizations.dart';
import '../../models/HomeFeatureModel.dart';
import '../../models/HomeLayoutSettings.dart';
import '../../utlis/app_router.dart';
import '../Expenses/view/ExpensesTitle.dart';
import '../Grocery/Grocery/view/grocery_title.dart';
import '../HomeScreen/controller/home_layout_provider.dart';
import '../HomeScreen/view/HomeScreenAlignment.dart';
import '../Multimedia/MultimediaDashboard.dart';
import '../Personal_diary/view/personal_diary_screen.dart';
import '../Settings/view/backupScreen.dart';
import '../Settings/view/primary_local_backups_screen.dart';
import '../Settings/view/legacy_backup_compatibility_screen.dart';
import '../device_sync/device_sync_screen.dart';
import '../database/view/DBinspectorScreen.dart';
import '../family_tree/view/family_tree_home_screen.dart';
import '../habitTracker/view/habit_desktop_dashboard.dart';
import '../quotation/view/quotation_desktop_dashboard.dart';
import '../invoices/view/invoice_desktop_dashboard.dart';
import '../loan/digital_khata_desktop_dashboard.dart';
import '../meter/MeterList/view/MeterListPage.dart';
import '../pill_reminder/desktop/pill_desktop_dashboard.dart';
import '../scanner/view/scanner_desktop_dashboard.dart';
import '../tutorials/tutorial_center_screen.dart';
import '../HomeScreen/controller/home_provider.dart';
import '../HomeScreen/widgets/home_direct_actions.dart';
import 'widgets/quick_create_sheet.dart';
import 'widgets/desktop_navigation_scope.dart';

part 'parts/main_navigation_shell_state.dart';
part 'parts/main_navigation_shell_desktop_sidebar.dart';
part 'parts/main_navigation_shell_app_navigation_rail.dart';

const double _desktopAdminBreakpoint = 1100;

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

