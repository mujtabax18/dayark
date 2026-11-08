part of '../ExpensesTitle.dart';

class _CategoryCard extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onToggleHidden;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onOpen,
    required this.onEdit,
    required this.onToggleHidden,
    required this.onDelete,
  });

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
    final count = (category['item_count'] as num?)?.toInt() ?? 0;

    return Opacity(
      opacity: hidden ? 0.72 : 1,
      child: Material(
        color: neutral.card,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onOpen,
          onLongPress: onEdit,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: color.withOpacity(0.22)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(child: CenteredFaIcon(icon, color: color, size: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category['title']?.toString() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: neutral.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (hidden) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.visibility_off_outlined,
                              size: 15,
                              color: neutral.textSecondary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$count transaction${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: neutral.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (totalOut > 0)
                            _AmountLabel(
                              icon: Icons.arrow_downward_rounded,
                              value: totalOut,
                              color: AppColors.danger,
                            ),
                          if (totalIn > 0)
                            _AmountLabel(
                              icon: Icons.arrow_upward_rounded,
                              value: totalIn,
                              color: AppColors.success,
                            ),
                          if (totalIn == 0 && totalOut == 0)
                            Text(
                              'No activity in selected period',
                              style: TextStyle(
                                color: neutral.textDisabled,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
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
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit style'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'hidden',
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        title: Text(hidden ? 'Show category' : 'Hide category'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                  icon: Icon(Icons.more_vert, color: neutral.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  final IconData icon;
  final double value;
  final Color color;

  const _AmountLabel({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 3),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HiddenCategoriesBanner extends StatelessWidget {
  final int hiddenCount;
  final bool showingHidden;
  final VoidCallback onTap;

  const _HiddenCategoriesBanner({
    required this.hiddenCount,
    required this.showingHidden,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: neutral.divider),
        ),
        child: Row(
          children: [
            Icon(
              showingHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.expense,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                showingHidden
                    ? 'Hidden categories are currently visible.'
                    : '$hiddenCount hidden categor${hiddenCount == 1 ? 'y' : 'ies'} still included in totals.',
                style: TextStyle(color: neutral.textSecondary, fontSize: 12),
              ),
            ),
            Text(
              showingHidden ? 'Hide' : 'Show',
              style: const TextStyle(
                color: AppColors.expense,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.showHidden});

  final bool showHidden;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: showHidden
          ? Icons.category_outlined
          : Icons.visibility_off_outlined,
      title: showHidden ? 'No categories yet' : 'All categories are hidden',
      message: showHidden
          ? 'Create a category to start tracking expenses.'
          : 'Use the menu to show hidden categories.',
      accent: AppColors.expense,
    );
  }
}
