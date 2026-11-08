import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/responsive_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../utlis/app_router.dart';
import '../../Settings/controller/backup_restore_Provider.dart';
import '../components/ExpenseSummaryWidget.dart';
import '../components/ExpenseBottomWidget.dart';
import '../components/addExpenseTitleWidget.dart';
import '../components/buildPopupMenu.dart';
import '../components/expense_category_form_sheet.dart';
import '../components/expense_category_style.dart';
import '../components/showFilterExpensesDialog.dart';
import '../controller/ExpensesController.dart';
import 'expense_reports_page.dart';
import 'expenses.dart';
import '../../../core/widgets/common/app_empty_state.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';

part 'parts/expenses_title_expenses_titles_page_state.dart';
part 'parts/expenses_title_desktop_expense_workspace.dart';
part 'parts/expenses_title_desktop_expense_overview.dart';
part 'parts/expenses_title_category_card.dart';

class ExpensesTitlesPage extends ConsumerStatefulWidget {
  const ExpensesTitlesPage({
    super.key,
    this.onDesktopBack,
  });

  /// Used by the desktop dashboard shell so the expense workspace can return
  /// to the original dashboard without leaving the shell.
  final VoidCallback? onDesktopBack;

  @override
  ConsumerState<ExpensesTitlesPage> createState() => _ExpensesTitlesPageState();
}

