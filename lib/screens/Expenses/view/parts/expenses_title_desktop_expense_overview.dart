part of '../ExpensesTitle.dart';

class _DesktopExpenseOverview extends StatelessWidget {
  const _DesktopExpenseOverview({
    required this.allCategories,
    required this.categories,
    required this.hiddenCount,
    required this.showingHidden,
    required this.onRefresh,
    required this.onToggleHiddenList,
    required this.onFilter,
    required this.onAddExpense,
    required this.onAdd,
    required this.overflowMenu,
    required this.onOpen,
    required this.onEdit,
    required this.onToggleCategoryHidden,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> allCategories;
  final List<Map<String, dynamic>> categories;
  final int hiddenCount;
  final bool showingHidden;
  final Future<void> Function() onRefresh;
  final VoidCallback onToggleHiddenList;
  final VoidCallback onFilter;
  final VoidCallback onAddExpense;
  final VoidCallback onAdd;
  final Widget overflowMenu;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onToggleCategoryHidden;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense management',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track cash flow, categories and transactions from one workspace.',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: onAddExpense,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.expense,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                icon: const Icon(Icons.add_card_outlined, size: 19),
                label: const Text(
                  'Add expense',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onFilter,
                icon: const Icon(Icons.filter_list_rounded, size: 19),
                label: const Text('Filter'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.create_new_folder_outlined, size: 19),
                label: const Text(
                  'Add category',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 42, height: 40, child: overflowMenu),
            ],
          ),
          const SizedBox(height: 24),
          ExpenseSummaryWidget(data: allCategories),
          if (hiddenCount > 0) ...[
            const SizedBox(height: 16),
            _HiddenCategoriesBanner(
              hiddenCount: hiddenCount,
              showingHidden: showingHidden,
              onTap: onToggleHiddenList,
            ),
          ],
          const SizedBox(height: 20),
          Container(
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
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense categories',
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${categories.length} shown • ${allCategories.length} total',
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: onRefresh,
                        icon: Icon(
                          Icons.refresh_rounded,
                          color: neutral.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: neutral.divider),
                if (categories.isEmpty)
                  SizedBox(
                    height: 310,
                    child: _EmptyCategories(showHidden: showingHidden),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth =
                          constraints.maxWidth < 1050 ? 1050.0 : constraints.maxWidth;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableWidth,
                          child: Column(
                            children: [
                              _DesktopCategoryHeader(neutral: neutral),
                              ...List.generate(categories.length, (index) {
                                final category = categories[index];
                                return _DesktopCategoryRow(
                                  category: category,
                                  showDivider:
                                      index != categories.length - 1,
                                  onOpen: () => onOpen(category),
                                  onEdit: () => onEdit(category),
                                  onToggleHidden: () =>
                                      onToggleCategoryHidden(category),
                                  onDelete: () => onDelete(category),
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
          ),
        ],
      ),
    );
  }
}

class _DesktopCategoryHeader extends StatelessWidget {
  const _DesktopCategoryHeader({required this.neutral});

  final dynamic neutral;

  @override
  Widget build(BuildContext context) {
    Text header(String value) => Text(
          value.toUpperCase(),
          style: TextStyle(
            color: neutral.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.45,
          ),
        );

    return Container(
      color: neutral.section.withOpacity(0.65),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          Expanded(flex: 34, child: header('Category')),
          Expanded(flex: 12, child: header('Transactions')),
          Expanded(flex: 14, child: header('Income')),
          Expanded(flex: 14, child: header('Expense')),
          Expanded(flex: 14, child: header('Balance')),
          Expanded(flex: 10, child: header('Status')),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _DesktopCategoryRow extends StatelessWidget {
  const _DesktopCategoryRow({
    required this.category,
    required this.showDivider,
    required this.onOpen,
    required this.onEdit,
    required this.onToggleHidden,
    required this.onDelete,
  });

  final Map<String, dynamic> category;
  final bool showDivider;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onToggleHidden;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color =
        ExpenseCategoryStyle.colorFromHex(category['color']?.toString());
    final icon = ExpenseCategoryStyle.iconFromCode(
      category['icon_code'],
      title: category['title']?.toString(),
    );
    final hidden = ((category['hidden'] as num?)?.toInt() ?? 0) == 1;
    final totalIn = (category['total_in'] as num?)?.toDouble() ?? 0;
    final totalOut = (category['total_out'] as num?)?.toDouble() ?? 0;
    final balance = totalIn - totalOut;
    final count = (category['item_count'] as num?)?.toInt() ?? 0;

    Widget amount(double value, Color amountColor) => Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            color: amountColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );

    return Opacity(
      opacity: hidden ? 0.7 : 1,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(bottom: BorderSide(color: neutral.divider))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 34,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CenteredFaIcon(icon, color: color, size: 19),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        category['title']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 12,
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: amount(totalIn, AppColors.success),
              ),
              Expanded(
                flex: 14,
                child: amount(totalOut, AppColors.danger),
              ),
              Expanded(
                flex: 14,
                child: amount(
                  balance,
                  balance >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
              Expanded(
                flex: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (hidden ? neutral.textSecondary : AppColors.success)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hidden ? 'Hidden' : 'Active',
                      style: TextStyle(
                        color: hidden
                            ? neutral.textSecondary
                            : AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: PopupMenuButton<String>(
                  tooltip: 'Category actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'hidden':
                        onToggleHidden();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'hidden',
                      child: Text(hidden ? 'Show category' : 'Hide category'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: neutral.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

