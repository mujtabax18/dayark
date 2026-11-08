import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_x.dart';
import '../../../controller/monthclosingController.dart';
import '../controller/ExpensesController.dart';

void showFilterExpensesDialog(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (_) => _ExpenseFilterDialog(parentRef: ref),
  );
}

class _ExpenseFilterDialog extends ConsumerStatefulWidget {
  final WidgetRef parentRef;

  const _ExpenseFilterDialog({required this.parentRef});

  @override
  ConsumerState<_ExpenseFilterDialog> createState() =>
      _ExpenseFilterDialogState();
}

class _ExpenseFilterDialogState
    extends ConsumerState<_ExpenseFilterDialog> {
  late String _closingId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _closingId = widget.parentRef.read(expenseItemFilterClosingIdProvider);
    _startDate = DateTime.tryParse(
      widget.parentRef.read(expenseItemFilterStartDateProvider) ?? '',
    );
    _endDate = DateTime.tryParse(
      widget.parentRef.read(expenseItemFilterEndDateProvider) ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final closings = ref.watch(monthClosingControllerProvider);

    return AlertDialog(
      backgroundColor: neutral.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Filter expenses',
        style: TextStyle(
          color: neutral.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            closings.when(
              data: (data) => DropdownButtonFormField<String>(
                value: _validClosingValue(data.map((e) => e.id.toString())),
                isExpanded: true,
                decoration: _decoration(context, 'Closing period'),
                items: [
                  const DropdownMenuItem(
                    value: 'latest',
                    child: Text('Current open period'),
                  ),
                  const DropdownMenuItem(
                    value: 'All',
                    child: Text('All transactions'),
                  ),
                  ...data.map(
                    (closing) => DropdownMenuItem(
                      value: closing.id.toString(),
                      child: Text(
                        closing.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _closingId = value);
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(
                'Could not load closings',
                style: TextStyle(color: neutral.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start date',
                    value: _startDate,
                    onTap: () => _pickDate(isStart: true),
                    onClear: () => setState(() => _startDate = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateField(
                    label: 'End date',
                    value: _endDate,
                    onTap: () => _pickDate(isStart: false),
                    onClear: () => setState(() => _endDate = null),
                  ),
                ),
              ],
            ),
            if (_startDate != null &&
                _endDate != null &&
                _endDate!.isBefore(_startDate!)) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'End date must be on or after start date.',
                  style: TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _reset,
          child: const Text(
            'Reset',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: neutral.textSecondary),
          ),
        ),
        FilledButton(
          onPressed: _canApply ? _apply : null,
          child: const Text('Apply'),
        ),
      ],
    );
  }

  bool get _canApply =>
      _startDate == null || _endDate == null || !_endDate!.isBefore(_startDate!);

  String _validClosingValue(Iterable<String> ids) {
    if (_closingId == 'latest' || _closingId.toLowerCase() == 'all') {
      return _closingId.toLowerCase() == 'all' ? 'All' : 'latest';
    }
    return ids.contains(_closingId) ? _closingId : 'latest';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _apply() {
    final parentRef = widget.parentRef;
    parentRef
        .read(expenseItemFilterClosingIdProvider.notifier)
        .setExpenseItemFilterClosingId(_closingId);
    parentRef
        .read(expenseItemFilterStartDateProvider.notifier)
        .setExpenseItemFilterStartDate(_format(_startDate));
    parentRef
        .read(expenseItemFilterEndDateProvider.notifier)
        .setExpenseItemFilterEndDate(_format(_endDate));
    parentRef.invalidate(expenseSummaryProvider);
    Navigator.pop(context);
  }

  void _reset() {
    final parentRef = widget.parentRef;
    parentRef
        .read(expenseItemFilterClosingIdProvider.notifier)
        .setExpenseItemFilterClosingId('latest');
    parentRef
        .read(expenseItemFilterStartDateProvider.notifier)
        .setExpenseItemFilterStartDate(null);
    parentRef
        .read(expenseItemFilterEndDateProvider.notifier)
        .setExpenseItemFilterEndDate(null);
    parentRef.invalidate(expenseSummaryProvider);
    Navigator.pop(context);
  }

  String? _format(DateTime? date) {
    return date == null ? null : DateFormat('yyyy-MM-dd').format(date);
  }

  InputDecoration _decoration(BuildContext context, String label) {
    final neutral = context.themeColors.neutral;
    return InputDecoration(
      labelText: label,
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
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: neutral.section,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: neutral.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: neutral.divider),
          ),
        ),
        child: Text(
          value == null ? 'Any date' : DateFormat('dd MMM yyyy').format(value!),
          style: TextStyle(color: neutral.textPrimary, fontSize: 13),
        ),
      ),
    );
  }
}
