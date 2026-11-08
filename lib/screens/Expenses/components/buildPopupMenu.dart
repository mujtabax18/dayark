import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../services/pdf/pdfgenerationfunction.dart';
import '../controller/ExpensesController.dart';
import '../view/expense_reports_page.dart';
import 'month_closing_sheet.dart';
import 'showFilterExpensesDialog.dart';

Widget buildPopupMenu(
  BuildContext context,
  backupNotifier,
  WidgetRef ref,
  String tableName, {
  bool includeReports = true,
  bool includeFilter = true,
}) {
  final neutral = context.themeColors.neutral;
  final showHidden = ref.watch(showHiddenExpenseCategoriesProvider);

  return PopupMenuButton<String>(
    icon: Icon(Icons.more_vert, color: neutral.textPrimary),
    color: neutral.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    onSelected: (value) async {
      switch (value) {
        case 'Share expense backup':
          if (!Platform.isLinux) {
            await backupNotifier.shareExpenses(context);
          }
          break;
        case 'Save expense backup':
          await backupNotifier.backupExpenses(context);
          break;
        case 'Restore backup':
          await backupNotifier.restoreExpenses(context);
          invalidateExpenseData(ref);
          break;
        case 'Filter':
          showFilterExpensesDialog(context, ref);
          break;
        case 'Refresh':
          invalidateExpenseData(ref);
          break;
        case 'Close month':
          await showExpenseMonthClosingSheet(context, ref);
          break;
        case 'Reports':
          if (context.mounted) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ExpenseReportsPage(),
              ),
            );
          }
          break;
        case 'Toggle hidden':
          ref.read(showHiddenExpenseCategoriesProvider.notifier).toggle();
          break;
        case 'Export PDF':
          final closingId = ref.read(expenseItemFilterClosingIdProvider);
          await generateAndShareExpenseReport(
            context: context,
            ref: ref,
            closingId: closingId,
          );
          break;
      }
    },
    itemBuilder: (_) => [
      if (includeReports)
        _menuItem(Icons.analytics_outlined, 'Reports', neutral),
      if (includeFilter)
        _menuItem(Icons.filter_list_rounded, 'Filter', neutral),
      _menuItem(Icons.calendar_month, 'Close month', neutral),
      _menuItem(
        showHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        showHidden ? 'Hide hidden categories' : 'Show hidden categories',
        neutral,
        value: 'Toggle hidden',
      ),
      const PopupMenuDivider(),
      _menuItem(Icons.picture_as_pdf_outlined, 'Export PDF', neutral),
      if (!Platform.isLinux)
        _menuItem(Icons.share_outlined, 'Share expense backup', neutral),
      _menuItem(Icons.backup_outlined, 'Save expense backup', neutral),
      _menuItem(Icons.restore, 'Restore backup', neutral),
      const PopupMenuDivider(),
      _menuItem(Icons.refresh, 'Refresh', neutral),
    ],
  );
}

PopupMenuItem<String> _menuItem(
  IconData icon,
  String label,
  dynamic neutral, {
  String? value,
}) {
  return PopupMenuItem<String>(
    value: value ?? label,
    child: Row(
      children: [
        Icon(icon, color: neutral.textSecondary, size: 20),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: neutral.textPrimary)),
      ],
    ),
  );
}
