part of '../ExpensesTitle.dart';

class _ExpensesTitlesPageState extends ConsumerState<ExpensesTitlesPage> {
  int? _selectedDesktopExpenseId;
  bool _showDesktopReports = false;

  void _showDesktopOverview() {
    if (_selectedDesktopExpenseId == null && !_showDesktopReports) return;
    setState(() {
      _selectedDesktopExpenseId = null;
      _showDesktopReports = false;
    });
  }

  void _openDesktopExpense(Map<String, dynamic> category) {
    final id = (category['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() {
      _selectedDesktopExpenseId = id;
      _showDesktopReports = false;
    });
  }

  void _showReports() {
    setState(() {
      _selectedDesktopExpenseId = null;
      _showDesktopReports = true;
    });
  }

  Future<void> _showAddExpenseDialog(
    List<Map<String, dynamic>> categories,
  ) async {
    final selectable = categories
        .where((category) => (category['id'] as num?)?.toInt() != null)
        .toList();
    if (selectable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create an expense category before adding a transaction.'),
        ),
      );
      return;
    }

    var selectedId = (selectable.first['id'] as num).toInt();
    final neutral = context.themeColors.neutral;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 620,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.9,
                ),
                child: Material(
                  color: neutral.card,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.expense.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_card_outlined,
                                color: AppColors.expense,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Add expense transaction',
                                    style: TextStyle(
                                      color: neutral.textPrimary,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Choose a category, then enter the transaction details.',
                                    style: TextStyle(
                                      color: neutral.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: Icon(
                                Icons.close_rounded,
                                color: neutral.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        DropdownButtonFormField<int>(
                          value: selectedId,
                          decoration: InputDecoration(
                            labelText: 'Expense category',
                            prefixIcon: const Icon(Icons.category_outlined),
                            filled: true,
                            fillColor: neutral.section,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: neutral.divider),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: neutral.divider),
                            ),
                          ),
                          items: selectable.map((category) {
                            final id = (category['id'] as num).toInt();
                            final title =
                                category['title']?.toString() ?? 'Expense category';
                            return DropdownMenuItem<int>(
                              value: id,
                              child: Text(title),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() => selectedId = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        AddExpenseWidget(
                          key: ValueKey('overview-add-expense-$selectedId'),
                          expenseId: selectedId,
                          desktopMode: true,
                          closeOnSave: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(expenseSummaryProvider);
    final backupNotifier = ref.read(backupRestoreProvider.notifier);
    final showHidden = ref.watch(showHiddenExpenseCategoriesProvider);
    final neutral = context.themeColors.neutral;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      backgroundColor: neutral.background,
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(
                'Expense management',
                style: TextStyle(color: neutral.textPrimary),
              ),
              centerTitle: true,
              backgroundColor: neutral.background,
              elevation: 0,
              actions: [
                buildPopupMenu(context, backupNotifier, ref, 'expense_items'),
              ],
            ),
      body: isDesktop
          ? summary.when(
              data: (allCategories) {
                final visibleCategories = allCategories
                    .where(
                      (row) =>
                          ((row['hidden'] as num?)?.toInt() ?? 0) == 0,
                    )
                    .toList();
                final categories =
                    showHidden ? allCategories : visibleCategories;
                final hiddenCount =
                    allCategories.length - visibleCategories.length;
                final selectedId = allCategories.any(
                  (category) =>
                      (category['id'] as num?)?.toInt() ==
                      _selectedDesktopExpenseId,
                )
                    ? _selectedDesktopExpenseId
                    : null;

                final content = _showDesktopReports
                    ? const ExpenseReportsPage()
                    : selectedId != null
                        ? ExpenseListPage(
                            key: ValueKey('expense-$selectedId'),
                            expenseId: selectedId,
                            embeddedDesktop: true,
                          )
                        : _DesktopExpenseOverview(
                            allCategories: allCategories,
                            categories: categories,
                            hiddenCount: hiddenCount,
                            showingHidden: showHidden,
                            onRefresh: () async {
                              ref.invalidate(expenseSummaryProvider);
                              await ref.read(expenseSummaryProvider.future);
                            },
                            onToggleHiddenList: () => ref
                                .read(
                                  showHiddenExpenseCategoriesProvider.notifier,
                                )
                                .toggle(),
                            onFilter: () =>
                                showFilterExpensesDialog(context, ref),
                            onAddExpense: () =>
                                _showAddExpenseDialog(allCategories),
                            onAdd: () =>
                                showExpenseCategoryFormSheet(context, ref),
                            overflowMenu: buildPopupMenu(
                              context,
                              backupNotifier,
                              ref,
                              'expense_items',
                              includeReports: false,
                              includeFilter: false,
                            ),
                            onOpen: _openDesktopExpense,
                            onEdit: (category) =>
                                showExpenseCategoryFormSheet(
                              context,
                              ref,
                              existing: category,
                            ),
                            onToggleCategoryHidden: (category) async {
                              final hidden =
                                  ((category['hidden'] as num?)?.toInt() ?? 0) ==
                                      1;
                              await ref
                                  .read(dbExpenseServiceProvider)
                                  .toggleCategory(
                                    (category['id'] as num).toInt(),
                                    !hidden,
                                  );
                              ref.invalidate(expenseSummaryProvider);
                              ref.invalidate(expenseCategoriesProvider);
                            },
                            onDelete: (category) => _confirmDelete(
                              context,
                              ref,
                              (category['id'] as num).toInt(),
                              category['title']?.toString() ?? 'Category',
                            ),
                          );

                return _DesktopExpenseWorkspace(
                  categories: categories,
                  selectedExpenseId: selectedId,
                  reportsSelected: _showDesktopReports,
                  onBackToDashboard: widget.onDesktopBack,
                  onOverviewSelected: _showDesktopOverview,
                  onReportsSelected: _showReports,
                  onExpenseSelected: _openDesktopExpense,
                  onAddCategory: () =>
                      showExpenseCategoryFormSheet(context, ref),
                  child: content,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 44,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Failed to load expense data.\n$error',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: neutral.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ref.invalidate(expenseSummaryProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ResponsivePageFrame(
              maxWidth: 1280,
              child: summary.when(
                data: (allCategories) {
                  final visibleCategories = allCategories
                      .where(
                        (row) =>
                            ((row['hidden'] as num?)?.toInt() ?? 0) == 0,
                      )
                      .toList();
                  final categories =
                      showHidden ? allCategories : visibleCategories;
                  final hiddenCount =
                      allCategories.length - visibleCategories.length;

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(expenseSummaryProvider);
                      await ref.read(expenseSummaryProvider.future);
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          sliver: SliverToBoxAdapter(
                            child: ExpenseSummaryWidget(data: allCategories),
                          ),
                        ),
                        if (hiddenCount > 0)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            sliver: SliverToBoxAdapter(
                              child: _HiddenCategoriesBanner(
                                hiddenCount: hiddenCount,
                                showingHidden: showHidden,
                                onTap: () => ref
                                    .read(
                                      showHiddenExpenseCategoriesProvider
                                          .notifier,
                                    )
                                    .toggle(),
                              ),
                            ),
                          ),
                        if (categories.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyCategories(showHidden: showHidden),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final category = categories[index];
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: index == categories.length - 1
                                          ? 0
                                          : 10,
                                    ),
                                    child: _CategoryCard(
                                      category: category,
                                      onOpen: () => context.push(
                                        '${RoutesStr.expenseItem}/${category['id']}',
                                      ),
                                      onEdit: () =>
                                          showExpenseCategoryFormSheet(
                                        context,
                                        ref,
                                        existing: category,
                                      ),
                                      onToggleHidden: () async {
                                        final hidden =
                                            ((category['hidden'] as num?)
                                                            ?.toInt() ??
                                                        0) ==
                                                    1;
                                        await ref
                                            .read(dbExpenseServiceProvider)
                                            .toggleCategory(
                                              (category['id'] as num).toInt(),
                                              !hidden,
                                            );
                                        ref.invalidate(expenseSummaryProvider);
                                        ref.invalidate(
                                          expenseCategoriesProvider,
                                        );
                                      },
                                      onDelete: () => _confirmDelete(
                                        context,
                                        ref,
                                        (category['id'] as num).toInt(),
                                        category['title']?.toString() ??
                                            'Category',
                                      ),
                                    ),
                                  );
                                },
                                childCount: categories.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                          size: 44,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Failed to load expense data.\n$error',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: neutral.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.invalidate(expenseSummaryProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
              decoration: BoxDecoration(
                color: neutral.card,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: const AddExpenseTitleWidget(),
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    int id,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Delete category?'),
          ],
        ),
        content: Text(
          '$title and all of its transactions will be hidden from the app. '
          'The records remain in backups as soft-deleted data.',
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
    try {
      await ref.read(deleteExpenseTitleProvider(id));
      if (_selectedDesktopExpenseId == id && mounted) {
        _showDesktopOverview();
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }
}

