import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_x.dart';
import '../../../../models/meter.dart';
import '../../shared/meter_catalog.dart';

Future<Meter?> showMeterFormSheet({
  required BuildContext context,
  Meter? meter,
}) {
  return showModalBottomSheet<Meter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MeterFormSheet(meter: meter),
  );
}

/// Compatibility wrapper for the old two-field dialog API.
Future<void> showAddMeterDialog({
  required BuildContext context,
  required Function(String name, String number) onAddMeter,
  Meter? meter,
}) async {
  final result = await showMeterFormSheet(context: context, meter: meter);
  if (result != null) {
    onAddMeter(result.name, result.number);
  }
}

class _MeterFormSheet extends StatefulWidget {
  final Meter? meter;

  const _MeterFormSheet({this.meter});

  @override
  State<_MeterFormSheet> createState() => _MeterFormSheetState();
}

class _MeterFormSheetState extends State<_MeterFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  late final TextEditingController _referenceController;
  late final TextEditingController _consumerController;
  late final TextEditingController _providerController;
  late final TextEditingController _locationController;
  late final TextEditingController _unitController;
  late final TextEditingController _baselineController;
  late final TextEditingController _targetUnitsController;
  late final TextEditingController _targetBudgetController;
  late final TextEditingController _unitRateController;
  late final TextEditingController _fixedChargesController;
  late final TextEditingController _customDaysController;
  late final TextEditingController _billingDayController;
  late final TextEditingController _notesController;

  late String _meterType;
  late String _tariffCategory;
  late String _frequency;
  late String _iconKey;
  late int _colorValue;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final meter = widget.meter;
    _nameController = TextEditingController(text: meter?.name ?? '');
    _numberController = TextEditingController(text: meter?.number ?? '');
    _referenceController =
        TextEditingController(text: meter?.referenceNumber ?? '');
    _consumerController =
        TextEditingController(text: meter?.consumerName ?? '');
    _providerController = TextEditingController(text: meter?.provider ?? '');
    _locationController = TextEditingController(text: meter?.location ?? '');
    _unitController = TextEditingController(text: meter?.unitLabel ?? 'kWh');
    _baselineController = TextEditingController(
      text: meter?.baseline == null ? '' : _number(meter!.baseline!),
    );
    _targetUnitsController = TextEditingController(
      text: meter?.targetUnits == null ? '' : _number(meter!.targetUnits!),
    );
    _targetBudgetController = TextEditingController(
      text: meter?.targetBudget == null ? '' : _number(meter!.targetBudget!),
    );
    _unitRateController = TextEditingController(
      text: meter == null || meter.unitRate == 0 ? '' : _number(meter.unitRate),
    );
    _fixedChargesController = TextEditingController(
      text: meter == null || meter.fixedCharges == 0
          ? ''
          : _number(meter.fixedCharges),
    );
    _customDaysController = TextEditingController(
      text: (meter?.customIntervalDays ?? 7).toString(),
    );
    _billingDayController = TextEditingController(
      text: (meter?.billingCycleDay ?? 1).toString(),
    );
    _notesController = TextEditingController(text: meter?.notes ?? '');

    _meterType = meter?.meterType ?? 'electricity';
    _tariffCategory = meter?.tariffCategory ?? 'residential';
    _frequency = meter?.readingFrequency ?? 'weekly';
    _iconKey = meter?.iconKey ?? _meterType;
    _colorValue = meter?.colorValue ?? MeterCatalog.colors.first;
    _isActive = meter?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _referenceController.dispose();
    _consumerController.dispose();
    _providerController.dispose();
    _locationController.dispose();
    _unitController.dispose();
    _baselineController.dispose();
    _targetUnitsController.dispose();
    _targetBudgetController.dispose();
    _unitRateController.dispose();
    _fixedChargesController.dispose();
    _customDaysController.dispose();
    _billingDayController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final editing = widget.meter != null;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.94,
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
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(_colorValue).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    MeterCatalog.iconFor(_iconKey),
                    color: Color(_colorValue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editing ? 'Edit meter' : 'Add a meter',
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Electricity, gas, water, solar or any custom meter',
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
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  24 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  _sectionTitle('Basic details'),
                  _field(
                    controller: _nameController,
                    label: 'Meter name *',
                    hint: 'e.g. Home main meter',
                    icon: Icons.speed_rounded,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Meter name is required'
                        : null,
                  ),
                  _twoColumns(
                    _field(
                      controller: _numberController,
                      label: 'Meter number',
                      hint: 'Optional',
                      icon: Icons.numbers_rounded,
                    ),
                    _field(
                      controller: _referenceController,
                      label: 'Reference / consumer no.',
                      hint: 'Bill reference',
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    value: _meterType,
                    decoration: _decoration(
                      label: 'Meter type',
                      icon: Icons.category_rounded,
                    ),
                    items: MeterCatalog.types
                        .map(
                          (type) => DropdownMenuItem(
                            value: type.key,
                            child: Row(
                              children: [
                                Icon(type.icon, size: 18),
                                const SizedBox(width: 10),
                                Text(type.label),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      final type = MeterCatalog.typeFor(value);
                      setState(() {
                        _meterType = value;
                        _iconKey = value;
                        _unitController.text = type.defaultUnit;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _providerController,
                    label: 'Provider / company',
                    hint: 'e.g. MEPCO, LESCO, SNGPL, WASA',
                    icon: Icons.apartment_rounded,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MeterCatalog.pakistanProviders.take(10).map((name) {
                      final selected = _providerController.text == name;
                      return ChoiceChip(
                        label: Text(name),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _providerController.text = name);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  _twoColumns(
                    _field(
                      controller: _consumerController,
                      label: 'Consumer name',
                      hint: 'Optional',
                      icon: Icons.person_outline_rounded,
                    ),
                    _field(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'Floor, shop, room',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle('Appearance'),
                  Text(
                    'Icon',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: MeterCatalog.types.map((type) {
                      final selected = _iconKey == type.key;
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => setState(() => _iconKey = type.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(_colorValue).withOpacity(0.16)
                                : neutral.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? Color(_colorValue)
                                  : neutral.divider,
                              width: selected ? 1.6 : 1,
                            ),
                          ),
                          child: Icon(
                            type.icon,
                            color: selected
                                ? Color(_colorValue)
                                : neutral.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Color',
                    style: TextStyle(
                      color: neutral.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: MeterCatalog.colors.map((value) {
                      final selected = _colorValue == value;
                      return InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => setState(() => _colorValue = value),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(color: neutral.textPrimary, width: 3)
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle('Reading plan'),
                  _twoColumns(
                    _field(
                      controller: _unitController,
                      label: 'Unit label',
                      hint: 'kWh, m³, L',
                      icon: Icons.straighten_rounded,
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Unit is required'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: _frequency,
                      decoration: _decoration(
                        label: 'Reading frequency',
                        icon: Icons.event_repeat_rounded,
                      ),
                      items: MeterCatalog.frequencies.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _frequency = value);
                      },
                    ),
                  ),
                  if (_frequency == 'custom') ...[
                    const SizedBox(height: 12),
                    _field(
                      controller: _customDaysController,
                      label: 'Repeat every (days)',
                      hint: 'e.g. 3',
                      icon: Icons.date_range_rounded,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final days = int.tryParse(value ?? '');
                        return days == null || days < 1
                            ? 'Enter at least 1 day'
                            : null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  _twoColumns(
                    _field(
                      controller: _baselineController,
                      label: 'Starting / baseline reading',
                      hint: 'Optional',
                      icon: Icons.flag_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _field(
                      controller: _billingDayController,
                      label: 'Billing cycle day',
                      hint: '1 - 28',
                      icon: Icons.calendar_month_rounded,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final day = int.tryParse(value ?? '');
                        return day == null || day < 1 || day > 28
                            ? 'Use a day from 1 to 28'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle('Targets and cost estimate'),
                  DropdownButtonFormField<String>(
                    value: _tariffCategory,
                    decoration: _decoration(
                      label: 'Tariff category',
                      icon: Icons.account_balance_rounded,
                    ),
                    items: MeterCatalog.tariffCategories.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _tariffCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _twoColumns(
                    _field(
                      controller: _targetUnitsController,
                      label: 'Monthly unit target',
                      hint: 'Optional',
                      icon: Icons.track_changes_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _field(
                      controller: _targetBudgetController,
                      label: 'Monthly budget (PKR)',
                      hint: 'Optional',
                      icon: Icons.payments_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _twoColumns(
                    _field(
                      controller: _unitRateController,
                      label: 'Simple rate / unit',
                      hint: 'PKR',
                      icon: Icons.price_change_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    _field(
                      controller: _fixedChargesController,
                      label: 'Fixed charges',
                      hint: 'PKR',
                      icon: Icons.receipt_outlined,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Use the meter detail screen to configure progressive tariff slabs. Rates are user-configurable because utility tariffs can change.',
                      style: TextStyle(
                        color: neutral.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _sectionTitle('Notes and status'),
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _decoration(
                      label: 'Notes',
                      icon: Icons.notes_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Active meter',
                      style: TextStyle(
                        color: neutral.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Inactive meters remain in history but are excluded from active tracking.',
                      style: TextStyle(color: neutral.textSecondary),
                    ),
                    value: _isActive,
                    activeColor: AppColors.primary,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: BoxDecoration(
              color: neutral.card,
              border: Border(top: BorderSide(color: neutral.divider)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submit,
                  icon: Icon(editing ? Icons.save_rounded : Icons.add_rounded),
                  label: Text(editing ? 'Save changes' : 'Add meter'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    final neutral = context.themeColors.neutral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          color: neutral.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _twoColumns(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              first,
              const SizedBox(height: 12),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _decoration(label: label, hint: hint, icon: icon),
    );
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.themeColors.neutral.divider),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.meter;
    final now = DateTime.now();
    final meter = Meter(
      id: existing?.id,
      name: _nameController.text.trim(),
      number: _numberController.text.trim(),
      baseline: _doubleOrNull(_baselineController.text),
      meterType: _meterType,
      provider: _providerController.text.trim(),
      location: _locationController.text.trim(),
      consumerName: _consumerController.text.trim(),
      referenceNumber: _referenceController.text.trim(),
      tariffCategory: _tariffCategory,
      unitLabel: _unitController.text.trim(),
      iconKey: _iconKey,
      colorValue: _colorValue,
      readingFrequency: _frequency,
      customIntervalDays: int.tryParse(_customDaysController.text) ?? 7,
      billingCycleDay: int.tryParse(_billingDayController.text) ?? 1,
      targetUnits: _doubleOrNull(_targetUnitsController.text),
      targetBudget: _doubleOrNull(_targetBudgetController.text),
      unitRate: _doubleOrNull(_unitRateController.text) ?? 0,
      fixedCharges: _doubleOrNull(_fixedChargesController.text) ?? 0,
      notes: _notesController.text.trim(),
      isActive: _isActive,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.pop(context, meter);
  }

  static double? _doubleOrNull(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  static String _number(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}
