import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../models/LoanModel.dart';
import '../../models/currency_setting.dart';
import 'khata_formatters.dart';

Future<LoanTransaction?> showKhataTransactionSheet(
  BuildContext context, {
  required LoanModel loan,
  required double outstanding,
  LoanTransaction? existing,
  String initialType = 'payment',
}) {
  return showModalBottomSheet<LoanTransaction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => KhataTransactionSheet(
      loan: loan,
      outstanding: outstanding,
      existing: existing,
      initialType: initialType,
    ),
  );
}

class KhataTransactionSheet extends StatefulWidget {
  const KhataTransactionSheet({
    super.key,
    required this.loan,
    required this.outstanding,
    this.existing,
    this.initialType = 'payment',
  });

  final LoanModel loan;
  final double outstanding;
  final LoanTransaction? existing;
  final String initialType;

  @override
  State<KhataTransactionSheet> createState() =>
      _KhataTransactionSheetState();
}

class _KhataTransactionSheetState extends State<KhataTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _referenceController;
  late String _transactionType;
  late String _paymentMethod;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amountController = TextEditingController(
      text: existing == null ? '' : _editableAmount(existing.amount),
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _referenceController =
        TextEditingController(text: existing?.referenceNumber ?? '');
    _transactionType = existing?.transactionType ?? widget.initialType;
    _paymentMethod = existing?.paymentMethod ?? 'cash';
    _date = DateTime.tryParse(existing?.date ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  bool get _reducesBalance =>
      _transactionType == 'payment' || _transactionType == 'discount';

  Color get _accent {
    return switch (_transactionType) {
      'payment' => AppColors.success,
      'discount' => AppColors.loan,
      'interest' => AppColors.warning,
      _ => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: neutral.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: neutral.divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existing == null
                              ? 'Add Ledger Entry'
                              : 'Edit Ledger Entry',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Outstanding: ${KhataFormatters.money(widget.outstanding, currencyCode: widget.loan.currencyCode)}',
                          style: TextStyle(
                            color: neutral.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: neutral.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: neutral.divider),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, bottomInset + 24),
                  children: [
                    _typeGrid(),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _amountController,
                      autofocus: widget.existing == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _decoration(
                        label: 'Amount',
                        icon: Icons.payments_outlined,
                        prefixText: '${_currencySymbol(widget.loan.currencyCode)} ',
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value?.trim() ?? '');
                        if (amount == null || amount <= 0) {
                          return 'Enter a valid amount';
                        }
                        if (_reducesBalance &&
                            widget.existing == null &&
                            amount > widget.outstanding + 0.005) {
                          return 'Amount cannot exceed the outstanding balance';
                        }
                        return null;
                      },
                    ),
                    if (_transactionType == 'payment') ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: _decoration(
                          label: 'Payment method',
                          icon: Icons.account_balance_outlined,
                        ),
                        items: const <String, String>{
                          'cash': 'Cash',
                          'bank': 'Bank transfer',
                          'easypaisa': 'Easypaisa',
                          'jazzcash': 'JazzCash',
                          'card': 'Card',
                          'other': 'Other',
                        }.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _paymentMethod = value);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _decoration(
                          label: 'Entry date',
                          icon: Icons.calendar_month_outlined,
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(_date),
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _referenceController,
                      decoration: _decoration(
                        label: 'Receipt / reference number',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: _decoration(
                        label: 'Note',
                        icon: Icons.notes_outlined,
                        hint: _defaultHint(),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _submit,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        widget.existing == null ? 'Save Entry' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _typeChip('payment', 'Payment', Icons.south_west, AppColors.success),
        _typeChip('charge', 'Add credit', Icons.add, AppColors.danger),
        _typeChip('interest', 'Add markup', Icons.percent, AppColors.warning),
        _typeChip('discount', 'Discount', Icons.local_offer_outlined, AppColors.loan),
      ],
    );
  }

  Widget _typeChip(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final neutral = context.themeColors.neutral;
    final selected = _transactionType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _transactionType = value;
          if (value != 'payment') _paymentMethod = 'other';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : neutral.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : neutral.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: selected ? Colors.white : color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : neutral.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    String? prefixText,
  }) {
    final neutral = context.themeColors.neutral;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: neutral.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutral.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: neutral.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _accent, width: 1.5),
      ),
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      useRootNavigator: false,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;

    setState(() {
      final time = pickedTime ?? TimeOfDay.fromDateTime(_date);
      _date = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final existing = widget.existing;
    Navigator.pop(
      context,
      LoanTransaction(
        id: existing?.id,
        loanId: widget.loan.id!,
        amount: double.parse(_amountController.text.trim()),
        date: _date.toIso8601String(),
        note: _noteController.text.trim(),
        transactionType: _transactionType,
        paymentMethod: _transactionType == 'payment'
            ? _paymentMethod
            : 'other',
        referenceNumber: _referenceController.text.trim(),
        createdAt: existing?.createdAt,
      ),
    );
  }

  String _defaultHint() {
    return switch (_transactionType) {
      'payment' => 'Payment received / paid',
      'charge' => 'New sale, loan or amount added',
      'interest' => 'Additional markup or service charge',
      'discount' => 'Discount or amount waived',
      _ => '',
    };
  }

  static String _currencySymbol(String code) {
    return CurrencySetting.presetByCode(code)?.symbol ?? code.trim();
  }

  static String _editableAmount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}
