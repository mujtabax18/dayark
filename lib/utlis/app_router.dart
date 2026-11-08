import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/common/app_route_error_screen.dart';
import '../models/meter.dart';
import '../screens/Expenses/view/ExpensesTitle.dart';
import '../screens/Expenses/view/expenses.dart';
import '../screens/family_tree/view/family_tree_home_screen.dart';
import '../screens/Grocery/Grocery/view/grocery_item.dart';
import '../screens/Grocery/Grocery/view/grocery_title.dart';
import '../screens/HomeScreen/view/HomeScreen.dart';
import '../screens/HomeScreen/view/HomeScreenAlignment.dart';
import '../screens/Multimedia/MultimediaDashboard.dart';
import '../screens/Personal_diary/view/personal_diary_screen.dart';
import '../screens/Settings/view/backupScreen.dart';
import '../screens/Settings/view/legacy_backup_compatibility_screen.dart';
import '../screens/Settings/view/primary_local_backups_screen.dart';
import '../screens/database/view/DBinspectorScreen.dart';
import '../screens/device_sync/device_sync_screen.dart';
import '../screens/habitTracker/view/HabitDetailScreen.dart';
import '../screens/habitTracker/view/HabitsScreen.dart';
import '../screens/habitTracker/view/habit_desktop_dashboard.dart';
import '../screens/habitTracker/view/QuotesScreen.dart' as legacy_quotes;
import '../screens/quotation/view/quotation_desktop_dashboard.dart';
import '../screens/invoices/data/invoice_model.dart';
import '../screens/invoices/view/InvoiceFormScreen.dart';
import '../screens/invoices/view/InvoiceViewScreen.dart';
import '../screens/invoices/view/invoice_desktop_dashboard.dart';
import '../screens/invoices/view/invoiceListScreen.dart';
import '../screens/loan/loan_dashboard.dart';
import '../screens/meter/MeterList/view/MeterListPage.dart';
import '../screens/meter/meterreading/view/meterreading.dart';
import '../screens/navigation/finance_screen.dart';
import '../screens/navigation/main_navigation_shell.dart';
import '../screens/navigation/more_screen.dart';
import '../screens/navigation/planner_screen.dart';
import '../screens/pill_reminder/pill_form/view/pill_form_screen.dart';
import '../screens/pill_reminder/pill_home/view/pill_home_screen.dart';
import '../screens/pill_reminder/pill_list/view/pill_list_screen.dart';
import '../screens/pill_reminder/pill_settings/view/pill_settings_screen.dart';
import '../screens/pill_reminder/profile/view/profile_screen.dart';
import '../screens/scanner/data/models/scan_model.dart';
import '../screens/scanner/view/ScanGroupViewScreen.dart';
import '../screens/scanner/view/pdf_viewer_screen.dart';
import '../screens/scanner/view/scanner_detail_screen.dart';
import '../screens/scanner/view/scanner_gallery_screen.dart';
import '../screens/scanner/view/scanner_desktop_dashboard.dart';
import '../screens/tutorials/tutorial_center_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: RoutesStr.home,
  errorBuilder: (context, state) => AppRouteErrorScreen(
    message: state.error?.toString() ??
        'The requested route does not exist or is missing required data.',
  ),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MainNavigationShell(
        navigationShell: navigationShell,
      ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutesStr.home,
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutesStr.finance,
              builder: (context, state) => const FinanceScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutesStr.planner,
              builder: (context, state) => const PlannerScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: RoutesStr.more,
              builder: (context, state) => const MoreScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: RoutesStr.scannerGallery,
      builder: (context, state) => MediaQuery.sizeOf(context).width >= 1100
          ? const ScannerDesktopDashboard()
          : const ScannerGalleryScreen(),
    ),
    GoRoute(
      path: RoutesStr.pdfViewer,
      builder: (context, state) {
        final file = state.extra;
        if (file is! File) {
          return const AppRouteErrorScreen(
            message: 'No PDF file was supplied to the viewer.',
          );
        }
        return PdfViewerScreen(file: file);
      },
    ),
    GoRoute(
      path: '/scanner/scan/:id',
      builder: (context, state) {
        final scan = state.extra;
        if (scan is! ScanEntry) {
          return const AppRouteErrorScreen(
            message: 'The selected scan is no longer available.',
          );
        }
        return ScannerDetailScreen(scan: scan);
      },
    ),
    GoRoute(
      path: '/scanner/group',
      builder: (context, state) {
        final groupId = state.extra;
        if (groupId is! int) {
          return const AppRouteErrorScreen(
            message: 'The scanner group identifier is missing.',
          );
        }
        return ScanGroupViewScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: RoutesStr.meterList,
      builder: (context, state) => MeterListPage(),
    ),
    GoRoute(
      path: RoutesStr.meterReading,
      builder: (context, state) {
        final meter = state.extra;
        if (meter is! Meter) {
          return const AppRouteErrorScreen(
            message: 'The selected meter is no longer available.',
          );
        }
        return MeterDetailPage(meter: meter);
      },
    ),
    GoRoute(
      path: RoutesStr.deviceSync,
      builder: (context, state) => const DeviceSyncScreen(),
    ),
    GoRoute(
      path: RoutesStr.backupCompatibility,
      builder: (context, state) => const LegacyBackupCompatibilityScreen(),
    ),
    GoRoute(
      path: RoutesStr.primaryLocalBackups,
      builder: (context, state) => const PrimaryLocalBackupsScreen(),
    ),
    GoRoute(
      path: RoutesStr.settings,
      builder: (context, state) => const SettingScreen(),
    ),
    GoRoute(
      path: RoutesStr.backup,
      builder: (context, state) => const SettingScreen(),
    ),
    GoRoute(
      path: RoutesStr.homeSetting,
      builder: (context, state) => const HomePageAlignment(),
    ),
    GoRoute(
      path: RoutesStr.grocery,
      builder: (context, state) => const GroceryTitlesPage(),
    ),
    GoRoute(
      path: RoutesStr.expense,
      builder: (context, state) => ExpensesTitlesPage(),
    ),
    GoRoute(
      path: '${RoutesStr.groceryItem}/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const AppRouteErrorScreen(
            message: 'The grocery list identifier is invalid.',
          );
        }
        return GroceryListPage(groceryId: id);
      },
    ),
    GoRoute(
      path: '${RoutesStr.expenseItem}/:id',
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const AppRouteErrorScreen(
            message: 'The expense list identifier is invalid.',
          );
        }
        return ExpenseListPage(expenseId: id);
      },
    ),
    GoRoute(
      path: RoutesStr.moodTracker,
      builder: (context, state) => PersonalDiaryScreen(),
    ),
    GoRoute(
      path: RoutesStr.quotes,
      builder: (context, state) =>
          MediaQuery.sizeOf(context).width >= 1100
              ? QuotationDesktopDashboard(
                  openCreateOnStart:
                      state.uri.queryParameters['create'] == '1',
                )
              : legacy_quotes.QuotesScreen(
                  openCreateOnStart:
                      state.uri.queryParameters['create'] == '1',
                ),
    ),
    GoRoute(
      path: RoutesStr.dataBaseViewer,
      builder: (context, state) => const DBInspectorScreen(),
    ),
    GoRoute(
      path: RoutesStr.habits,
      builder: (context, state) =>
          MediaQuery.sizeOf(context).width >= 1100
              ? const HabitDesktopDashboard()
              : const HabitsScreen(),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) {
              return const AppRouteErrorScreen(
                message: 'The habit identifier is invalid.',
              );
            }
            return MediaQuery.sizeOf(context).width >= 1100
                ? HabitDesktopDashboard(initialHabitId: id)
                : HabitDetailScreen(habitId: id);
          },
        ),
      ],
    ),
    GoRoute(
      path: RoutesStr.invoices,
      builder: (context, state) =>
          MediaQuery.sizeOf(context).width >= 1100
              ? const InvoiceDesktopDashboard()
              : const InvoiceListScreen(),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) =>
              MediaQuery.sizeOf(context).width >= 1100
                  ? const InvoiceDesktopDashboard(openCreateOnStart: true)
                  : const InvoiceFormScreen(),
        ),
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              MediaQuery.sizeOf(context).width >= 1100
                  ? InvoiceDesktopDashboard(
                      initialInvoiceId: state.pathParameters['id']!,
                    )
                  : InvoiceViewScreen(
                      id: state.pathParameters['id']!,
                    ),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (context, state) {
                final invoice = state.extra;
                return MediaQuery.sizeOf(context).width >= 1100
                    ? InvoiceDesktopDashboard(
                        initialInvoiceId: state.pathParameters['id']!,
                        openEditOnStart: true,
                        initialEditInvoice:
                            invoice is Invoice ? invoice : null,
                      )
                    : InvoiceFormScreen(
                        invoice: invoice is Invoice ? invoice : null,
                      );
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: RoutesStr.loans,
      builder: (context, state) => LoanDashboard(),
    ),
    GoRoute(
      path: RoutesStr.multimedia,
      builder: (context, state) => const MultimediaDashboard(),
    ),
    GoRoute(
      path: RoutesStr.pillReminder,
      builder: (context, state) => const PillHomeScreen(),
    ),
    GoRoute(
      path: RoutesStr.pillReminderForm,
      builder: (context, state) => const PillFormScreen(),
    ),
    GoRoute(
      path: RoutesStr.pillReminderProfile,
      builder: (context, state) => const PillProfileScreen(),
    ),
    GoRoute(
      path: RoutesStr.pillReminderPillList,
      builder: (context, state) => const PillListScreen(),
    ),
    GoRoute(
      path: RoutesStr.pillReminderSetting,
      builder: (context, state) => const PillSettingsScreen(),
    ),
    GoRoute(
      path: RoutesStr.tutorials,
      builder: (context, state) => const TutorialCenterScreen(),
    ),
    GoRoute(
      path: RoutesStr.familyTrees,
      builder: (context, state) => const FamilyTreeHomeScreen(),
    ),
  ],
);

abstract final class RoutesStr {
  static const home = '/';
  static const finance = '/finance';
  static const planner = '/planner';
  static const more = '/more';
  static const scannerGallery = '/scanner-gallery';
  static const pdfViewer = '/pdf-viewer';
  static const homeSetting = '/homeSetting';
  static const meterList = '/meter';
  static const meterReading = '/meterReading';
  static const settings = '/settings';
  static const deviceSync = '/device-sync';
  static const primaryLocalBackups = '/settings/primary-local-backups';
  static const backupCompatibility = '/backup-compatibility';
  static const backup = '/backup';
  static const grocery = '/grocery';
  static const expense = '/expenses';
  static const groceryItem = '/groceryItem';
  static const expenseItem = '/expenseItem';
  static const moodTracker = '/mood';
  static const habits = '/habits';
  static const habitDetail = '/habitDetail';
  static const quotes = '/quotes';
  static const invoices = '/invoices';
  static const dataBaseViewer = '/dataBaseViewer';
  static const loans = '/loans';
  static const multimedia = '/multimedia';
  static const pillReminder = '/pill-reminder';
  static const pillReminderPillList = '/pill-reminder-list';
  static const pillReminderSetting = '/pill-reminder-setting';
  static const pillReminderProfile = '/pill-reminder-profile';
  static const pillReminderForm = '/pill-reminder-form';
  static const tutorials = '/tutorials';
  static const familyTrees = '/family-trees';
}
