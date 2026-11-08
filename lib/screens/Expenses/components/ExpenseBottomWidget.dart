import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../models/ExpenseItem.dart';
import '../../../utlis/constant.dart';
import '../controller/ExpensesController.dart';

class AddExpenseWidget extends ConsumerStatefulWidget {
  final int? expenseId;
  final ExpenseItem? existingExpense;
  final bool desktopMode;
  final bool closeOnSave;
  final bool showDesktopCloseButton;
  final String? categoryLabel;

  const AddExpenseWidget({
    super.key,
    this.expenseId,
    this.existingExpense,
    this.desktopMode = false,
    this.closeOnSave = false,
    this.showDesktopCloseButton = false,
    this.categoryLabel,
  });

  @override
  ConsumerState<AddExpenseWidget> createState() => _AddExpenseWidgetState();
}

class _AddExpenseWidgetState extends ConsumerState<AddExpenseWidget> {
  late DateTime selectedDate;
  late TextEditingController itemNameController;
  late TextEditingController itemPriceController;
  late TextEditingController itemNotesController;
  late bool inOut;
  late bool isEditing;
  bool _saving = false;

  int get _expenseId => widget.expenseId ?? widget.existingExpense?.expenseId ?? 0;

  @override
  void initState() {
    super.initState();
    isEditing = widget.existingExpense != null;
    selectedDate = widget.existingExpense?.date ?? DateTime.now();
    itemNameController = TextEditingController(
      text: widget.existingExpense?.name ?? '',
    );
    itemPriceController = TextEditingController(
      text: widget.existingExpense?.price?.toStringAsFixed(2) ?? '',
    );
    itemNotesController = TextEditingController(
      text: widget.existingExpense?.notes ?? '',
    );
    inOut = widget.existingExpense?.inOrOut == ConstantTableString.itemIn;
  }

  @override
  void dispose() {
    itemNameController.dispose();
    itemPriceController.dispose();
    itemNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    if (_saving) return;
    final name = itemNameController.text.trim();
    final amount = double.tryParse(itemPriceController.text.trim());
    if (name.isEmpty || amount == null || amount < 0 || _expenseId <= 0) {
      _showMessage('Enter a valid item name and amount.');
      return;
    }

    setState(() => _saving = true);
    try {
      final expenseItem = ExpenseItem(
        id: widget.existingExpense?.id,
        uuid: widget.existingExpense?.uuid,
        name: name,
        date: selectedDate,
        expenseId: _expenseId,
        inOrOut:
            inOut ? ConstantTableString.itemIn : ConstantTableString.itemOut,
        notes: itemNotesController.text.trim(),
        price: amount,
        closingId: widget.existingExpense?.closingId,
        creationDate: widget.existingExpense?.creationDate,
      );

      final service = ref.read(dbExpenseServiceProvider);
      if (isEditing) {
        final changed = await service.editExpenseItem(expenseItem);
        if (changed == 0) {
          _showMessage('This transaction is no longer available.');
          return;
        }
      } else {
        await service.addExpenseItem(expenseItem: expenseItem);
      }

      invalidateExpenseData(ref, categoryId: _expenseId);
      if (!mounted) return;
      if (isEditing || widget.closeOnSave) {
        if (!isEditing) {
          _showMessage('Transaction added.');
        }
        Navigator.pop(context);
      } else {
        itemNameController.clear();
        itemPriceController.clear();
        itemNotesController.clear();
        _showMessage('Transaction added.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteExpense() async {
    final id = widget.existingExpense?.id;
    if (id == null) return;
    final changed = await ref.read(dbExpenseServiceProvider).deleteExpenseItem(id);
    if (changed == 0) {
      _showMessage('This transaction is no longer available.');
      return;
    }
    invalidateExpenseData(ref, categoryId: _expenseId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final typeColor = inOut ? AppColors.success : AppColors.danger;

    if (widget.desktopMode) {
      return _buildDesktopForm(neutral, typeColor);
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, isEditing ? 16 : 10, 12, 10),
        decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: isEditing
              ? const BorderRadius.vertical(top: Radius.circular(22))
              : BorderRadius.circular(14),
          border: Border.all(color: neutral.divider.withOpacity(0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit transaction',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: neutral.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: itemNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: neutral.textPrimary),
                    decoration: _inputDecoration(
                      neutral,
                      hint: 'Item name',
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.expense,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: itemPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    style: TextStyle(color: neutral.textPrimary),
                    decoration: _inputDecoration(
                      neutral,
                      hint: 'Amount',
                      icon: inOut
                          ? Icons.arrow_circle_up_outlined
                          : Icons.arrow_circle_down_outlined,
                      iconColor: typeColor,
                      onIconTap: () => setState(() => inOut = !inOut),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: itemNotesController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveExpense(),
                    style: TextStyle(color: neutral.textPrimary),
                    decoration: _inputDecoration(
                      neutral,
                      hint: 'Notes (optional)',
                      icon: Icons.notes_outlined,
                      iconColor: neutral.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: Text(DateFormat('dd/MM/yy').format(selectedDate)),
                ),
                if (isEditing)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _deleteExpense,
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                  ),
                IconButton(
                  tooltip: isEditing ? 'Save changes' : 'Add transaction',
                  onPressed: _saving ? null : _saveExpense,
                  icon: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                          size: 27,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopForm(dynamic neutral, Color typeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: neutral.divider.withOpacity(0.75)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.expense.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.add_card_outlined,
                  color: AppColors.expense,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit transaction' : 'New transaction',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEditing
                          ? 'Update the transaction details below.'
                          : 'Add income or an expense to this category.',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showDesktopCloseButton)
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: neutral.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (widget.categoryLabel?.trim().isNotEmpty == true) ...[
            Text(
              'Expense category',
              style: TextStyle(
                color: neutral.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: neutral.section,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neutral.divider.withOpacity(0.65)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 19,
                    color: AppColors.expense,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.categoryLabel!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: neutral.textDisabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Transaction type',
            style: TextStyle(
              color: neutral.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _desktopTypeButton(
                  neutral,
                  label: 'Expense',
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.danger,
                  selected: !inOut,
                  onTap: () => setState(() => inOut = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _desktopTypeButton(
                  neutral,
                  label: 'Income',
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.success,
                  selected: inOut,
                  onTap: () => setState(() => inOut = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: itemNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: neutral.textPrimary),
            decoration: _desktopInputDecoration(
              neutral,
              label: 'Item name',
              hint: 'e.g. Office supplies',
              icon: Icons.receipt_long_outlined,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: itemPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: TextStyle(color: neutral.textPrimary),
            decoration: _desktopInputDecoration(
              neutral,
              label: 'Amount',
              hint: '0.00',
              icon: Icons.payments_outlined,
              iconColor: typeColor,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: itemNotesController,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveExpense(),
            maxLines: 3,
            minLines: 2,
            style: TextStyle(color: neutral.textPrimary),
            decoration: _desktopInputDecoration(
              neutral,
              label: 'Notes',
              hint: 'Optional details',
              icon: Icons.notes_outlined,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              decoration: BoxDecoration(
                color: neutral.section,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: neutral.divider.withOpacity(0.65)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 19,
                    color: neutral.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction date',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: neutral.textDisabled,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (isEditing) ...[
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _deleteExpense,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 19),
                      label: const Text('Delete'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: isEditing ? 2 : 1,
                child: SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveExpense,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.expense,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEditing
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            size: 20,
                          ),
                    label: Text(
                      _saving
                          ? (isEditing ? 'Saving...' : 'Adding...')
                          : (isEditing
                              ? 'Save changes'
                              : 'Add transaction'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopTypeButton(
    dynamic neutral, {
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : neutral.section,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? color.withOpacity(0.5) : neutral.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : neutral.textSecondary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : neutral.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _desktopInputDecoration(
    dynamic neutral, {
    required String label,
    required String hint,
    required IconData icon,
    Color? iconColor,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: neutral.textSecondary, fontSize: 12),
      hintStyle: TextStyle(color: neutral.textDisabled, fontSize: 12),
      filled: true,
      fillColor: neutral.section,
      prefixIcon: Icon(
        icon,
        color: iconColor ?? neutral.textSecondary,
        size: 19,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: neutral.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: neutral.divider.withOpacity(0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.expense, width: 1.4),
      ),
    );
  }

  InputDecoration _inputDecoration(
    dynamic neutral, {
    required String hint,
    required IconData icon,
    required Color iconColor,
    VoidCallback? onIconTap,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: neutral.textDisabled, fontSize: 13),
      isDense: true,
      filled: true,
      fillColor: neutral.section,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 11),
      prefixIcon: GestureDetector(
        onTap: onIconTap,
        child: Icon(icon, color: iconColor, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
