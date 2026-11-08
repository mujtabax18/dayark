import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../controller/currency_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_x.dart';
import '../../models/LoanModel.dart';

Future<LoanModel?> showKhataAccountForm(
  BuildContext context, {
  LoanModel? existing,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= 900;

  if (isDesktop) {
    return showDialog<LoanModel>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (_) => KhataAccountFormSheet(existing: existing),
    );
  }

  return showModalBottomSheet<LoanModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => KhataAccountFormSheet(existing: existing),
  );
}

class KhataAccountFormSheet extends ConsumerStatefulWidget {
  const KhataAccountFormSheet({super.key, this.existing});

  final LoanModel? existing;

  @override
  ConsumerState<KhataAccountFormSheet> createState() =>
      _KhataAccountFormSheetState();
}

class _KhataAccountFormSheetState
    extends ConsumerState<KhataAccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _desktopScrollController = ScrollController();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _amountController;
  late final TextEditingController _interestController;
  late final TextEditingController _installmentController;
  late final TextEditingController _reminderDaysController;
  late final TextEditingController _referenceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  late int _loanType;
  late String _currencyCode;
  late String _installmentFrequency;
  late bool _reminderEnabled;
  late DateTime _startDate;
  DateTime? _dueDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final account = widget.existing;
    _nameController = TextEditingController(text: account?.entityName ?? '');
    _phoneController = TextEditingController(text: account?.phone ?? '');
    _amountController = TextEditingController(
      text: account == null ? '' : _editableAmount(account.amount),
    );
    _interestController = TextEditingController(
      text: account == null || account.interestAmount == 0
          ? ''
          : _editableAmount(account.interestAmount),
    );
    _installmentController = TextEditingController(
      text: account == null || account.installmentAmount == 0
          ? ''
          : _editableAmount(account.installmentAmount),
    );
    _reminderDaysController = TextEditingController(
      text: '${account?.reminderDaysBefore ?? 3}',
    );
    _referenceController =
        TextEditingController(text: account?.referenceNumber ?? '');
    _categoryController =
        TextEditingController(text: account?.category ?? 'General');
    _addressController = TextEditingController(text: account?.address ?? '');
    _notesController = TextEditingController(text: account?.notes ?? '');

    _loanType = account?.loanType ?? 0;
    final appCurrency = ref.read(currencyProvider);
    _currencyCode = account?.currencyCode ??
        (appCurrency.isCustom ? appCurrency.symbol : appCurrency.code);
    _installmentFrequency = account?.installmentFrequency ?? 'none';
    _reminderEnabled = account?.reminderEnabled ?? true;
    _startDate = DateTime.tryParse(account?.startDate ?? '') ?? DateTime.now();
    _dueDate = account?.dueDateTime;
  }

  @override
  void dispose() {
    _desktopScrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _interestController.dispose();
    _installmentController.dispose();
    _reminderDaysController.dispose();
    _referenceController.dispose();
    _categoryController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return isDesktop ? _buildDesktopForm(context) : _buildMobileForm(context);
  }

  Widget _buildDesktopForm(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1120,
          maxHeight: size.height * 0.90,
          minWidth: size.width >= 1180 ? 960 : 760,
        ),
        child: Material(
          color: neutral.background,
          elevation: 18,
          shadowColor: Colors.black.withOpacity(0.18),
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _desktopHeader(),
                Divider(height: 1, color: neutral.divider),
                Flexible(
                  child: Scrollbar(
                    controller: _desktopScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      controller: _desktopScrollController,
                      padding: const EdgeInsets.fromLTRB(24, 20, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _directionSelector(),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final gap = constraints.maxWidth >= 900 ? 24.0 : 18.0;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _desktopLeftColumn()),
                                  SizedBox(width: gap),
                                  Expanded(child: _desktopRightColumn()),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, color: neutral.divider),
                _desktopFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 16, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.loan.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.menu_book_outlined, color: AppColors.loan),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Khata Account' : 'New Khata Account',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add the contact, opening balance and repayment details.',
                  style: TextStyle(color: neutral.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, color: neutral.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _desktopLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _desktopSectionCard(
          title: 'Customer / Person',
          icon: Icons.person_outline,
          child: Column(
            children: [
              _field(
                controller: _nameController,
                label: 'Name *',
                icon: Icons.person_outline,
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _phoneController,
                label: 'WhatsApp number',
                hint: 'Example: 923001234567',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _categoryController,
                      label: 'Category',
                      icon: Icons.category_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _referenceController,
                      label: 'Reference no.',
                      icon: Icons.tag,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _desktopSectionCard(
          title: 'Opening Balance',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            children: [
              _field(
                controller: _amountController,
                label: 'Principal amount ($_currencyCode) *',
                icon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _positiveAmountValidator,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _interestController,
                label: 'Interest / markup (optional)',
                icon: Icons.percent,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _nonNegativeAmountValidator,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _desktopSectionCard(
          title: 'Additional Details',
          icon: Icons.notes_outlined,
          child: Column(
            children: [
              _field(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _notesController,
                label: 'Notes / terms',
                icon: Icons.notes_outlined,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopRightColumn() {
    final neutral = context.themeColors.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _desktopSectionCard(
          title: 'Dates & Installments',
          icon: Icons.event_note_outlined,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      label: 'Start date',
                      value: _startDate,
                      onTap: _pickStartDate,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(
                      label: 'Due date',
                      value: _dueDate,
                      placeholder: 'Optional',
                      canClear: _dueDate != null,
                      onClear: () => setState(() => _dueDate = null),
                      onTap: _pickDueDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _installmentFrequency,
                decoration: _decoration(
                  label: 'Installment schedule',
                  icon: Icons.event_repeat_outlined,
                ),
                items: const <String, String>{
                  'none': 'No fixed schedule',
                  'daily': 'Daily',
                  'weekly': 'Weekly',
                  'monthly': 'Monthly',
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
                    setState(() => _installmentFrequency = value);
                  }
                },
              ),
              if (_installmentFrequency != 'none') ...[
                const SizedBox(height: 12),
                _field(
                  controller: _installmentController,
                  label: 'Expected installment amount',
                  icon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _positiveAmountValidator,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _desktopSectionCard(
          title: 'Reminder',
          icon: Icons.notifications_active_outlined,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: neutral.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: neutral.divider),
                ),
                child: SwitchListTile.adaptive(
                  value: _reminderEnabled,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  onChanged: (value) {
                    setState(() => _reminderEnabled = value);
                  },
                  title: Text(
                    'Due-date reminder',
                    style: TextStyle(
                      color: neutral.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Highlight this account before payment is due',
                    style: TextStyle(color: neutral.textSecondary),
                  ),
                  activeColor: AppColors.loan,
                ),
              ),
              if (_reminderEnabled) ...[
                const SizedBox(height: 12),
                _field(
                  controller: _reminderDaysController,
                  label: 'Remind days before due date',
                  icon: Icons.notifications_active_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final days = int.tryParse(value?.trim() ?? '');
                    if (days == null || days < 0 || days > 365) {
                      return 'Enter 0 to 365 days';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (_loanType == 0 ? AppColors.success : AppColors.danger)
                .withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (_loanType == 0 ? AppColors.success : AppColors.danger)
                  .withOpacity(0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _loanType == 0 ? Icons.south_west : Icons.north_east,
                size: 20,
                color: _loanType == 0 ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _loanType == 0
                      ? 'This Khata will be tracked as money you need to receive.'
                      : 'This Khata will be tracked as money you need to pay.',
                  style: TextStyle(
                    color: neutral.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: neutral.section.withOpacity(0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.loan),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _desktopFooter() {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(foregroundColor: neutral.textSecondary),
          ),
          const Spacer(),
          SizedBox(
            width: 220,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _loanType == 0 ? AppColors.success : AppColors.danger,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                _isEditing ? 'Save Changes' : 'Create Khata Account',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileForm(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.94,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Khata Account' : 'New Khata Account',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Contact, opening balance and repayment plan',
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
                    _directionSelector(),
                    const SizedBox(height: 18),
                    _sectionTitle('Customer / Person'),
                    const SizedBox(height: 10),
                    _field(
                      controller: _nameController,
                      label: 'Name *',
                      icon: Icons.person_outline,
                      textCapitalization: TextCapitalization.words,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _phoneController,
                      label: 'WhatsApp number',
                      hint: 'Example: 923001234567',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _categoryController,
                            label: 'Category',
                            icon: Icons.category_outlined,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            controller: _referenceController,
                            label: 'Reference no.',
                            icon: Icons.tag,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Opening Balance'),
                    const SizedBox(height: 10),
                    _field(
                      controller: _amountController,
                      label: 'Principal amount ($_currencyCode) *',
                      icon: Icons.account_balance_wallet_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _positiveAmountValidator,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _interestController,
                      label: 'Interest / markup (optional)',
                      icon: Icons.percent,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: _nonNegativeAmountValidator,
                    ),
                    const SizedBox(height: 18),
                    _sectionTitle('Dates & Installments'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _dateField(
                            label: 'Start date',
                            value: _startDate,
                            onTap: _pickStartDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dateField(
                            label: 'Due date',
                            value: _dueDate,
                            placeholder: 'Optional',
                            canClear: _dueDate != null,
                            onClear: () => setState(() => _dueDate = null),
                            onTap: _pickDueDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _installmentFrequency,
                      decoration: _decoration(
                        label: 'Installment schedule',
                        icon: Icons.event_repeat_outlined,
                      ),
                      items: const <String, String>{
                        'none': 'No fixed schedule',
                        'daily': 'Daily',
                        'weekly': 'Weekly',
                        'monthly': 'Monthly',
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
                          setState(() => _installmentFrequency = value);
                        }
                      },
                    ),
                    if (_installmentFrequency != 'none') ...[
                      const SizedBox(height: 12),
                      _field(
                        controller: _installmentController,
                        label: 'Expected installment amount',
                        icon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: _positiveAmountValidator,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle('Reminder'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: neutral.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: neutral.divider),
                      ),
                      child: SwitchListTile.adaptive(
                        value: _reminderEnabled,
                        onChanged: (value) {
                          setState(() => _reminderEnabled = value);
                        },
                        title: Text(
                          'Due-date reminder',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Highlight this account before payment is due',
                          style: TextStyle(color: neutral.textSecondary),
                        ),
                        activeColor: AppColors.loan,
                      ),
                    ),
                    if (_reminderEnabled) ...[
                      const SizedBox(height: 12),
                      _field(
                        controller: _reminderDaysController,
                        label: 'Remind days before due date',
                        icon: Icons.notifications_active_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final days = int.tryParse(value?.trim() ?? '');
                          if (days == null || days < 0 || days > 365) {
                            return 'Enter 0 to 365 days';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    _sectionTitle('Additional Details'),
                    const SizedBox(height: 10),
                    _field(
                      controller: _addressController,
                      label: 'Address',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _notesController,
                      label: 'Notes / terms',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _loanType == 0 ? AppColors.success : AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _submit,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(
                        _isEditing ? 'Save Changes' : 'Create Khata Account',
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

  Widget _directionSelector() {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: neutral.section,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _directionButton(
            label: 'I will receive',
            subtitle: 'Customer owes me',
            icon: Icons.south_west,
            selected: _loanType == 0,
            color: AppColors.success,
            onTap: () => setState(() => _loanType = 0),
          ),
          const SizedBox(width: 6),
          _directionButton(
            label: 'I will pay',
            subtitle: 'I owe this person',
            icon: Icons.north_east,
            selected: _loanType == 1,
            color: AppColors.danger,
            onTap: () => setState(() => _loanType = 1),
          ),
        ],
      ),
    );
  }

  Widget _directionButton({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final neutral = context.themeColors.neutral;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected ? Colors.white : neutral.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withOpacity(0.82)
                            : neutral.textSecondary,
                        fontSize: 10,
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.themeColors.neutral.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      decoration: _decoration(label: label, icon: icon, hint: hint),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    final neutral = context.themeColors.neutral;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: neutral.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        borderSide: const BorderSide(color: AppColors.loan, width: 1.5),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    String placeholder = 'Select date',
    bool canClear = false,
    VoidCallback? onClear,
  }) {
    final neutral = context.themeColors.neutral;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 9, 8, 9),
        decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: neutral.divider),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 20, color: neutral.textSecondary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value == null
                        ? placeholder
                        : DateFormat('dd MMM yyyy').format(value),
                    style: TextStyle(
                      color: value == null
                          ? neutral.textDisabled
                          : neutral.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (canClear)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: Icon(Icons.close, size: 17, color: neutral.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_dueDate != null && _dueDate!.isBefore(picked)) {
          _dueDate = picked;
        }
      });
    }
  }

  Future<void> _pickDueDate() async {
    final initial = _dueDate ?? _startDate.add(const Duration(days: 30));
    final picked = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: initial.isBefore(_startDate) ? _startDate : initial,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 7300)),
    );
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  String? _positiveAmountValidator(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    return null;
  }

  String? _nonNegativeAmountValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final amount = double.tryParse(value.trim());
    if (amount == null || amount < 0) return 'Enter a valid amount';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.existing;
    final result = LoanModel(
      id: existing?.id,
      entityName: _nameController.text.trim(),
      loanType: _loanType,
      amount: double.parse(_amountController.text.trim()),
      interestAmount:
          double.tryParse(_interestController.text.trim()) ?? 0,
      startDate: _startDate.toIso8601String(),
      dueDate: _dueDate?.toIso8601String(),
      status: existing?.status ?? 0,
      notes: _notesController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? 'General'
          : _categoryController.text.trim(),
      referenceNumber: _referenceController.text.trim(),
      currencyCode: _currencyCode,
      installmentFrequency: _installmentFrequency,
      installmentAmount: _installmentFrequency == 'none'
          ? 0
          : double.tryParse(_installmentController.text.trim()) ?? 0,
      reminderEnabled: _reminderEnabled,
      reminderDaysBefore:
          int.tryParse(_reminderDaysController.text.trim()) ?? 3,
      lastReminderAt: existing?.lastReminderAt,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
      archivedAt: existing?.archivedAt,
    );

    Navigator.pop(context, result);
  }

  static String _editableAmount(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}
