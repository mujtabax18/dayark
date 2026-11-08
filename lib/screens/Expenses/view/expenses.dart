import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/ExpenseItem.dart';
import '../../../utlis/constant.dart';
import '../../Settings/controller/backup_restore_Provider.dart';
import '../components/ExpenseBottomWidget.dart';
import '../components/confirmDelete.dart';
import '../components/expense_category_style.dart';
import '../components/showFilterExpensesDialog.dart';
import '../components/showItemDetails.dart';
import '../controller/ExpensesController.dart';
import '../../../core/widgets/common/app_empty_state.dart';
import '../../../core/widgets/common/centered_fa_icon.dart';
import '../../navigation/widgets/desktop_content_frame.dart';
part '../components/expense_list_widgets.dart';

class ExpenseListPage extends ConsumerStatefulWidget {
  final int expenseId;
  final bool embeddedDesktop;

  const ExpenseListPage({
    super.key,
    required this.expenseId,
    this.embeddedDesktop = false,
  });

  @override
  ConsumerState<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends ConsumerState<ExpenseListPage> {
  final Set<int> _selectedIds = <int>{};

  bool get _selectionMode => _selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(expenseItemsProvider(widget.expenseId));
    final categoryAsync = ref.watch(expenseCategoryProvider(widget.expenseId));
    final backupNotifier = ref.read(backupRestoreProvider.notifier);
    final closingFilter = ref.watch(expenseItemFilterClosingIdProvider);
    final isSpecificClosedPeriod =
        closingFilter != 'latest' && closingFilter.toLowerCase() != 'all';
    final neutral = context.themeColors.neutral;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    final category = categoryAsync.asData?.value;
    final categoryColor = ExpenseCategoryStyle.colorFromHex(
      category?['color']?.toString(),
      fallback: AppColors.expense,
    );
    final categoryIcon = ExpenseCategoryStyle.iconFromCode(
      category?['icon_code'],
      title: category?['title']?.toString(),
    );

    if (isDesktop) {
      return _buildDesktopPage(
        itemsAsync: itemsAsync,
        category: category,
        categoryColor: categoryColor,
        categoryIcon: categoryIcon,
        backupNotifier: backupNotifier,
        isSpecificClosedPeriod: isSpecificClosedPeriod,
      );
    }

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: _selectionMode
          ? _selectionAppBar(itemsAsync.asData?.value ?? <ExpenseItem>[])
          : AppBar(
              backgroundColor: neutral.background,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              title: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: CenteredFaIcon(
                      categoryIcon,
                      color: categoryColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category?['title']?.toString() ?? 'Expense list',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          _filterLabel(ref),
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [_buildPopupMenu(context, backupNotifier)],
            ),
      body: DesktopContentFrame(
        child: itemsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return _EmptyItems(color: categoryColor, icon: categoryIcon);
            }
            final totalIn = items
                .where((item) => item.inOrOut == ConstantTableString.itemIn)
                .fold<double>(0, (sum, item) => sum + (item.price ?? 0));
            final totalOut = items
                .where((item) => item.inOrOut != ConstantTableString.itemIn)
                .fold<double>(0, (sum, item) => sum + (item.price ?? 0));

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(expenseItemsProvider(widget.expenseId));
                await ref.read(expenseItemsProvider(widget.expenseId).future);
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
                itemCount: items.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CategoryTotals(
                        totalIn: totalIn,
                        totalOut: totalOut,
                        color: categoryColor,
                      ),
                    );
                  }
                  final item = items[index - 1];
                  return _buildItem(context, item, categoryColor, categoryIcon);
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load transactions.\n$error',
                textAlign: TextAlign.center,
                style: TextStyle(color: neutral.textSecondary),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selectionMode
          ? null
          : isSpecificClosedPeriod
          ? _ClosedPeriodBar(
              onShowOpenPeriod: () {
                ref
                    .read(expenseItemFilterClosingIdProvider.notifier)
                    .setExpenseItemFilterClosingId('latest');
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: neutral.card,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: neutral.divider.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AddExpenseWidget(expenseId: widget.expenseId),
              ),
            ),
    );
  }

  Future<void> _showAddTransactionDialog(Map<String, dynamic>? category) async {
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: AddExpenseWidget(
            expenseId: widget.expenseId,
            desktopMode: true,
            closeOnSave: true,
            showDesktopCloseButton: true,
            categoryLabel:
                category?['title']?.toString() ?? 'Selected category',
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPage({
    required AsyncValue<List<ExpenseItem>> itemsAsync,
    required Map<String, dynamic>? category,
    required Color categoryColor,
    required FaIconData categoryIcon,
    required dynamic backupNotifier,
    required bool isSpecificClosedPeriod,
  }) {
    final neutral = context.themeColors.neutral;
    final title = category?['title']?.toString() ?? 'Expense list';

    final desktopContent = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: CenteredFaIcon(
                  categoryIcon,
                  color: categoryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _filterLabel(ref),
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSpecificClosedPeriod)
                OutlinedButton.icon(
                  onPressed: () {
                    ref
                        .read(expenseItemFilterClosingIdProvider.notifier)
                        .setExpenseItemFilterClosingId('latest');
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: const Text('Active month'),
                )
              else
                FilledButton.icon(
                  onPressed: () => _showAddTransactionDialog(category),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text(
                    'Add transaction',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => showFilterExpensesDialog(context, ref),
                icon: const Icon(Icons.filter_list_rounded, size: 19),
                label: const Text('Filter'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(expenseItemsProvider(widget.expenseId));
                  ref.invalidate(expenseCategoryProvider(widget.expenseId));
                },
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 4),
              _buildPopupMenu(context, backupNotifier),
            ],
          ),
        ),
        Divider(height: 1, color: neutral.divider),
        Expanded(
          child: itemsAsync.when(
            data: (items) {
              final totalIn = items
                  .where((item) => item.inOrOut == ConstantTableString.itemIn)
                  .fold<double>(0, (sum, item) => sum + (item.price ?? 0));
              final totalOut = items
                  .where((item) => item.inOrOut != ConstantTableString.itemIn)
                  .fold<double>(0, (sum, item) => sum + (item.price ?? 0));

              final transactions = _buildDesktopTransactionsCard(
                items,
                categoryColor,
                categoryIcon,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(expenseItemsProvider(widget.expenseId));
                  await ref.read(expenseItemsProvider(widget.expenseId).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
                  children: [
                    _DesktopCategoryTotals(
                      totalIn: totalIn,
                      totalOut: totalOut,
                      transactionCount: items.length,
                      color: categoryColor,
                    ),
                    const SizedBox(height: 18),
                    transactions,
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.danger,
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Could not load transactions.\n$error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: neutral.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.invalidate(
                        expenseItemsProvider(widget.expenseId),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: neutral.background,
      body: widget.embeddedDesktop
          ? desktopContent
          : DesktopContentFrame(maxWidth: 1480, child: desktopContent),
    );
  }

  Widget _buildDesktopTransactionsCard(
    List<ExpenseItem> items,
    Color categoryColor,
    FaIconData categoryIcon,
  ) {
    final neutral = context.themeColors.neutral;
    final selectableIds = items
        .where((item) => item.id != null)
        .map((item) => item.id!)
        .toSet();
    final allSelected =
        selectableIds.isNotEmpty && _selectedIds.containsAll(selectableIds);

    return Container(
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider.withOpacity(0.75)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
            child: _selectionMode
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Clear selection',
                            onPressed: () =>
                                setState(() => _selectedIds.clear()),
                            icon: const Icon(Icons.close_rounded),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_selectedIds.length} transaction${_selectedIds.length == 1 ? '' : 's'} selected',
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (allSelected) {
                                  _selectedIds.clear();
                                } else {
                                  _selectedIds
                                    ..clear()
                                    ..addAll(selectableIds);
                                }
                              });
                            },
                            icon: Icon(
                              allSelected ? Icons.deselect : Icons.select_all,
                              size: 18,
                            ),
                            label: Text(
                              allSelected ? 'Clear all' : 'Select all',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _moveSelected,
                            icon: const Icon(
                              Icons.drive_file_move_outline,
                              size: 18,
                            ),
                            label: const Text('Move'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _deleteSelected,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transactions',
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${items.length} record${items.length == 1 ? '' : 's'} in the selected view',
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Divider(height: 1, color: neutral.divider),
          if (items.isEmpty)
            SizedBox(
              height: 320,
              child: _EmptyItems(color: categoryColor, icon: categoryIcon),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableWidth = constraints.maxWidth < 900
                    ? 900.0
                    : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        _buildDesktopTableHeader(),
                        ...List.generate(items.length, (index) {
                          return _buildDesktopItemRow(
                            items[index],
                            categoryColor,
                            categoryIcon,
                            showDivider: index != items.length - 1,
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopTableHeader() {
    final neutral = context.themeColors.neutral;
    Text label(String value) => Text(
      value.toUpperCase(),
      style: TextStyle(
        color: neutral.textSecondary,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.45,
      ),
    );

    return Container(
      color: neutral.section.withOpacity(0.65),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 38),
          Expanded(flex: 24, child: label('Transaction')),
          Expanded(flex: 14, child: label('Date')),
          Expanded(flex: 22, child: label('Notes')),
          Expanded(flex: 12, child: label('Type')),
          Expanded(flex: 12, child: label('Amount')),
          Expanded(flex: 10, child: label('Period')),
          const SizedBox(width: 108),
        ],
      ),
    );
  }

  Widget _buildDesktopItemRow(
    ExpenseItem item,
    Color categoryColor,
    FaIconData categoryIcon, {
    required bool showDivider,
  }) {
    final neutral = context.themeColors.neutral;
    final id = item.id ?? 0;
    final selected = _selectedIds.contains(id);
    final isIncome = item.inOrOut == ConstantTableString.itemIn;
    final isClosed = item.closingId != null;
    final typeColor = isIncome ? AppColors.success : AppColors.danger;

    return Material(
      color: selected ? categoryColor.withOpacity(0.07) : Colors.transparent,
      child: InkWell(
        onTap: () => showItemDetails(context, item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: neutral.divider))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Checkbox(
                  value: selected,
                  onChanged: id <= 0 ? null : (_) => _toggleSelection(id),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Expanded(
                flex: 24,
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: CenteredFaIcon(
                        categoryIcon,
                        color: categoryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  DateFormat('dd MMM yyyy').format(item.date),
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
              Expanded(
                flex: 22,
                child: Text(
                  item.notes?.trim().isNotEmpty == true
                      ? item.notes!.trim()
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.notes?.trim().isNotEmpty == true
                        ? neutral.textSecondary
                        : neutral.textDisabled,
                    fontSize: 11.5,
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () async {
                      final newStatus = isIncome
                          ? ConstantTableString.itemOut
                          : ConstantTableString.itemIn;
                      await ref
                          .read(dbExpenseServiceProvider)
                          .updateGroceryInOUt(item.id!, newStatus);
                      invalidateExpenseData(ref, categoryId: widget.expenseId);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isIncome
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: typeColor,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isIncome ? 'Income' : 'Expense',
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  (item.price ?? 0).toStringAsFixed(2),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                flex: 10,
                child: Text(
                  isClosed ? 'Closed' : 'Open',
                  style: TextStyle(
                    color: isClosed ? neutral.textSecondary : AppColors.success,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(
                width: 108,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'View details',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      onPressed: () => showItemDetails(context, item),
                      icon: Icon(
                        Icons.visibility_outlined,
                        size: 18,
                        color: neutral.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      onPressed: () => _showEditSheet(item),
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: neutral.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      onPressed: () async {
                        final confirmed = await confirmDelete(context);
                        if (confirmed == true) {
                          final changed = await ref
                              .read(dbExpenseServiceProvider)
                              .deleteExpenseItem(item.id!);
                          _showMutationResult(changed, 1, 'deleted');
                          invalidateExpenseData(
                            ref,
                            categoryId: widget.expenseId,
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _selectionAppBar(List<ExpenseItem> items) {
    final neutral = context.themeColors.neutral;
    final selectableIds = items
        .where((item) => item.id != null)
        .map((item) => item.id!)
        .toSet();
    final allSelected =
        selectableIds.isNotEmpty && _selectedIds.containsAll(selectableIds);

    return AppBar(
      backgroundColor: neutral.card,
      leading: IconButton(
        onPressed: () => setState(() => _selectedIds.clear()),
        icon: const Icon(Icons.close),
      ),
      title: Text('${_selectedIds.length} selected'),
      actions: [
        IconButton(
          tooltip: allSelected ? 'Clear selection' : 'Select all',
          onPressed: () {
            setState(() {
              if (allSelected) {
                _selectedIds.clear();
              } else {
                _selectedIds
                  ..clear()
                  ..addAll(selectableIds);
              }
            });
          },
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
        ),
        IconButton(
          tooltip: 'Move to category',
          onPressed: _moveSelected,
          icon: const Icon(Icons.drive_file_move_outline),
        ),
        IconButton(
          tooltip: 'Delete selected',
          onPressed: _deleteSelected,
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    ExpenseItem item,
    Color categoryColor,
    FaIconData categoryIcon,
  ) {
    final neutral = context.themeColors.neutral;
    final id = item.id ?? 0;
    final selected = _selectedIds.contains(id);
    final isIncome = item.inOrOut == ConstantTableString.itemIn;
    final isClosed = item.closingId != null;
    final typeColor = isIncome ? AppColors.success : AppColors.danger;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? categoryColor.withOpacity(0.1) : neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? categoryColor : categoryColor.withOpacity(0.18),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (_selectionMode) {
            _toggleSelection(id);
          } else {
            showItemDetails(context, item);
          }
        },
        onLongPress: () => _toggleSelection(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? categoryColor
                      : categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 22)
                      : CenteredFaIcon(
                          categoryIcon,
                          color: categoryColor,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isClosed) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: neutral.section,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 11,
                                  color: neutral.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'Closed',
                                  style: TextStyle(
                                    color: neutral.textSecondary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy').format(item.date),
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (item.notes?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.notes!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neutral.textDisabled,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (item.price ?? 0).toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: typeColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () async {
                      final newStatus = isIncome
                          ? ConstantTableString.itemOut
                          : ConstantTableString.itemIn;
                      await ref
                          .read(dbExpenseServiceProvider)
                          .updateGroceryInOUt(item.id!, newStatus);
                      invalidateExpenseData(ref, categoryId: widget.expenseId);
                    },
                    child: Icon(
                      isIncome
                          ? Icons.arrow_circle_up_outlined
                          : Icons.arrow_circle_down_outlined,
                      color: typeColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
              if (!_selectionMode)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  onSelected: (value) async {
                    if (value == 'details') {
                      showItemDetails(context, item);
                    } else if (value == 'edit') {
                      _showEditSheet(item);
                    } else if (value == 'delete') {
                      final confirmed = await confirmDelete(context);
                      if (confirmed == true) {
                        final changed = await ref
                            .read(dbExpenseServiceProvider)
                            .deleteExpenseItem(item.id!);
                        _showMutationResult(changed, 1, 'deleted');
                        invalidateExpenseData(
                          ref,
                          categoryId: widget.expenseId,
                        );
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'details',
                      child: Text('View details'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('expense-$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) async {
        await ref.read(dbExpenseServiceProvider).deleteExpenseItem(id);
        invalidateExpenseData(ref, categoryId: widget.expenseId);
      },
      child: card,
    );
  }

  void _toggleSelection(int id) {
    if (id <= 0) return;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _moveSelected() async {
    final categories = await ref.read(expenseCategoriesProvider.future);
    if (!mounted) return;
    final targets = categories
        .where((row) => (row['id'] as num).toInt() != widget.expenseId)
        .toList();
    if (targets.isEmpty) {
      _showMessage('Create another category before moving transactions.');
      return;
    }

    final targetId = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final neutral = dialogContext.themeColors.neutral;
        return AlertDialog(
          title: const Text('Move selected items'),
          content: SizedBox(
            width: 420,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: targets.length,
              separatorBuilder: (_, __) => Divider(color: neutral.divider),
              itemBuilder: (_, index) {
                final category = targets[index];
                final color = ExpenseCategoryStyle.colorFromHex(
                  category['color']?.toString(),
                );
                final icon = ExpenseCategoryStyle.iconFromCode(
                  category['icon_code'],
                  title: category['title']?.toString(),
                );
                final hidden =
                    ((category['hidden'] as num?)?.toInt() ?? 0) == 1;
                return ListTile(
                  onTap: () => Navigator.pop(
                    dialogContext,
                    (category['id'] as num).toInt(),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.14),
                    child: CenteredFaIcon(icon, color: color),
                  ),
                  title: Text(category['title']?.toString() ?? ''),
                  subtitle: hidden ? const Text('Hidden category') : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (targetId == null) return;

    final requested = _selectedIds.length;
    final changed = await ref
        .read(dbExpenseServiceProvider)
        .moveExpenseItems(_selectedIds.toList(), targetId);
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    invalidateExpenseData(ref, categoryId: widget.expenseId);
    ref.invalidate(expenseItemsProvider(targetId));
    ref.invalidate(expenseCategoryProvider(targetId));
    _showMutationResult(changed, requested, 'moved');
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete selected items?'),
        content: const Text(
          'The selected transactions will be deleted from the period you are currently viewing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final requested = _selectedIds.length;
    final changed = await ref
        .read(dbExpenseServiceProvider)
        .deleteExpenseItems(_selectedIds.toList());
    if (!mounted) return;
    setState(() => _selectedIds.clear());
    invalidateExpenseData(ref, categoryId: widget.expenseId);
    _showMutationResult(changed, requested, 'deleted');
  }

  Future<void> _showEditSheet(ExpenseItem item) async {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    if (isDesktop) {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(32),
          child: SizedBox(
            width: 520,
            child: AddExpenseWidget(
              expenseId: widget.expenseId,
              existingExpense: item,
              desktopMode: true,
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: AddExpenseWidget(
            expenseId: widget.expenseId,
            existingExpense: item,
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, dynamic backupNotifier) {
    final neutral = context.themeColors.neutral;
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: neutral.textPrimary),
      onSelected: (value) async {
        switch (value) {
          case 'Share':
            if (!Platform.isLinux) {
              await backupNotifier.shareExpenseCategory(
                context,
                widget.expenseId,
              );
            }
            break;
          case 'Backup':
            await backupNotifier.backupExpenseCategory(
              context,
              widget.expenseId,
            );
            break;
          case 'Restore':
            await backupNotifier.restoreExpenses(context);
            invalidateExpenseData(ref, categoryId: widget.expenseId);
            break;
        }
      },
      itemBuilder: (_) => [
        if (!Platform.isLinux)
          _popupItem(Icons.share_outlined, 'Share', neutral),
        _popupItem(Icons.backup_outlined, 'Backup', neutral),
        _popupItem(Icons.restore, 'Restore', neutral),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(
    IconData icon,
    String label,
    dynamic neutral,
  ) {
    return PopupMenuItem(
      value: label,
      child: Row(
        children: [
          Icon(icon, color: neutral.textPrimary),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: neutral.textPrimary)),
        ],
      ),
    );
  }

  String _filterLabel(WidgetRef ref) {
    final closing = ref.watch(expenseItemFilterClosingIdProvider);
    final start = ref.watch(expenseItemFilterStartDateProvider);
    final end = ref.watch(expenseItemFilterEndDateProvider);
    final parts = <String>[];
    if (closing == 'latest') {
      parts.add('Open period');
    } else if (closing.toLowerCase() == 'all') {
      parts.add('All periods');
    } else {
      parts.add('Closing #$closing');
    }
    if (start != null || end != null) {
      parts.add('${start ?? 'Any'} – ${end ?? 'Any'}');
    }
    return parts.join(' • ');
  }

  void _showMutationResult(int changed, int requested, String action) {
    if (changed == requested) {
      _showMessage('$changed item${changed == 1 ? '' : 's'} $action.');
    } else {
      _showMessage(
        '$changed of $requested items were $action. Some records may already have changed.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
