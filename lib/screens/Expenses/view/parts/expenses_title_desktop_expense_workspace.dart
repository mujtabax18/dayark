part of '../ExpensesTitle.dart';

class _DesktopExpenseWorkspace extends StatelessWidget {
  const _DesktopExpenseWorkspace({
    required this.categories,
    required this.selectedExpenseId,
    required this.reportsSelected,
    required this.onBackToDashboard,
    required this.onOverviewSelected,
    required this.onReportsSelected,
    required this.onExpenseSelected,
    required this.onAddCategory,
    required this.child,
  });

  final List<Map<String, dynamic>> categories;
  final int? selectedExpenseId;
  final bool reportsSelected;
  final VoidCallback? onBackToDashboard;
  final VoidCallback onOverviewSelected;
  final VoidCallback onReportsSelected;
  final ValueChanged<Map<String, dynamic>> onExpenseSelected;
  final VoidCallback onAddCategory;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    final hasNestedSelection = selectedExpenseId != null || reportsSelected;

    return Row(
      children: [
        Container(
          width: 268,
          decoration: BoxDecoration(
            color: neutral.card,
            border: Border(
              right: BorderSide(color: neutral.divider.withOpacity(.85)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasNestedSelection || onBackToDashboard != null) ...[
                      OutlinedButton.icon(
                        onPressed: hasNestedSelection
                            ? onOverviewSelected
                            : onBackToDashboard,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hasNestedSelection
                                ? 'Back to expense overview'
                                : 'Back to dashboard',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.expense.withOpacity(.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.payments_outlined,
                            color: AppColors.expense,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expenses',
                                style: TextStyle(
                                  color: neutral.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Workspace',
                                style: TextStyle(
                                  color: neutral.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add expense list',
                          onPressed: onAddCategory,
                          icon: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: neutral.divider),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
                  children: [
                    _ExpenseWorkspaceNavItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Expense overview',
                      selected:
                          selectedExpenseId == null && !reportsSelected,
                      onTap: onOverviewSelected,
                    ),
                    _ExpenseWorkspaceNavItem(
                      icon: Icons.analytics_outlined,
                      label: 'Reports',
                      selected: reportsSelected,
                      onTap: onReportsSelected,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'EXPENSE LISTS',
                              style: TextStyle(
                                color: neutral.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .8,
                              ),
                            ),
                          ),
                          Text(
                            '${categories.length}',
                            style: TextStyle(
                              color: neutral.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (categories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'No expense lists yet.',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      for (final category in categories)
                        _ExpenseWorkspaceCategoryItem(
                          category: category,
                          selected: selectedExpenseId ==
                              (category['id'] as num?)?.toInt(),
                          onTap: () => onExpenseSelected(category),
                        ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withOpacity(.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: neutral.divider.withOpacity(.7)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: neutral.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select any list to manage its transactions on the right.',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 10.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: neutral.background,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _ExpenseWorkspaceNavItem extends StatelessWidget {
  const _ExpenseWorkspaceNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.primary : neutral.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? scheme.primary.withOpacity(.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 19, color: foreground),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? scheme.primary : neutral.textPrimary,
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseWorkspaceCategoryItem extends StatelessWidget {
  const _ExpenseWorkspaceCategoryItem({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final color = ExpenseCategoryStyle.colorFromHex(
      category['color']?.toString(),
      fallback: AppColors.expense,
    );
    final icon = ExpenseCategoryStyle.iconFromCode(
      category['icon_code'],
      title: category['title']?.toString(),
    );
    final count = (category['item_count'] as num?)?.toInt() ?? 0;
    final hidden = ((category['hidden'] as num?)?.toInt() ?? 0) == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? color.withOpacity(.11) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: CenteredFaIcon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category['title']?.toString() ?? 'Expense list',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontSize: 12,
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (hidden)
                            Icon(
                              Icons.visibility_off_outlined,
                              size: 13,
                              color: neutral.textSecondary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count transaction${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

