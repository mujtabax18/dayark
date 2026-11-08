part of '../dashboard_quick_actions.dart';

class _QuickSelectionSheet<T> extends StatelessWidget {
  const _QuickSelectionSheet({
    required this.title,
    required this.items,
    required this.itemBuilder,
  });

  final String title;
  final List<T> items;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) => itemBuilder(items[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickExpenseSheet extends ConsumerStatefulWidget {
  const _QuickExpenseSheet();

  @override
  ConsumerState<_QuickExpenseSheet> createState() => _QuickExpenseSheetState();
}

class _QuickExpenseSheetState extends ConsumerState<_QuickExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  int? _categoryId;
  bool _isIncome = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: AppRadius.medium,
                    ),
                    child: Icon(
                      Icons.add_card_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick transaction',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        Text(
                          'Choose a category and save without leaving home.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.arrow_downward_rounded),
                    label: Text('Expense'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.arrow_upward_rounded),
                    label: Text('Income'),
                  ),
                ],
                selected: {_isIncome},
                onSelectionChanged: (selection) {
                  setState(() => _isIncome = selection.first);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Unable to load categories: $error'),
                data: (categories) {
                  final visibleCategories = categories
                      .where((category) =>
                          (category['hidden'] as num? ?? 0).toInt() == 0)
                      .toList(growable: false);
                  if (visibleCategories.isEmpty) {
                    return _EmptyCategoryMessage(
                      onOpenExpenses: () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push(RoutesStr.expense);
                      },
                    );
                  }
                  final validSelection = visibleCategories.any(
                    (category) =>
                        (category['id'] as num).toInt() == _categoryId,
                  );
                  if (!validSelection) {
                    _categoryId =
                        (visibleCategories.first['id'] as num).toInt();
                  }
                  return DropdownButtonFormField<int>(
                    value: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Expense category',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: visibleCategories
                        .map(
                          (category) => DropdownMenuItem<int>(
                            value: (category['id'] as num).toInt(),
                            child: Text(category['title']?.toString() ?? ''),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) => setState(() => _categoryId = value),
                    validator: (value) =>
                        value == null ? 'Choose a category' : null,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title'
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (PKR)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  return amount == null || amount <= 0
                      ? 'Enter a valid amount'
                      : null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_saving ? 'Saving…' : 'Save transaction'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final categoryId = _categoryId;
    if (categoryId == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(dbExpenseServiceProvider).addExpenseItem(
            expenseItem: ExpenseItem(
              name: _nameController.text.trim(),
              date: DateTime.now(),
              expenseId: categoryId,
              price: double.parse(_amountController.text.trim()),
              inOrOut: _isIncome
                  ? ConstantTableString.itemIn
                  : ConstantTableString.itemOut,
              notes: _notesController.text.trim(),
            ),
          );
      invalidateExpenseData(ref, categoryId: categoryId);
      ref.invalidate(homeDashboardProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isIncome ? 'Income added.' : 'Expense added.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save transaction: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EmptyCategoryMessage extends StatelessWidget {
  const _EmptyCategoryMessage({required this.onOpenExpenses});

  final VoidCallback onOpenExpenses;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.medium,
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child:
                Text('Create an expense category before adding a transaction.'),
          ),
          TextButton(
            onPressed: onOpenExpenses,
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

