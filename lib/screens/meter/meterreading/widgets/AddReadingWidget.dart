import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_x.dart';
import '../../../../models/meter.dart';
import '../../../../services/localDatabaseServices/MeterService.dart';
import '../../MeterList/controller/meter_provider.dart';
import '../../shared/meter_catalog.dart';

part 'parts/add_reading_widget_state.dart';

Future<Reading?> showReadingFormSheet({
  required BuildContext context,
  required Meter meter,
  required List<MeterTariffSlab> tariffSlabs,
  required List<Reading> readings,
  MeterBaselineAnchor? baselineAnchor,
  Reading? reading,
}) {
  return showModalBottomSheet<Reading>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReadingFormSheet(
      meter: meter,
      tariffSlabs: tariffSlabs,
      readings: readings,
      baselineAnchor: baselineAnchor,
      reading: reading,
    ),
  );
}

class _ReadingFormSheet extends StatefulWidget {
  final Meter meter;
  final List<MeterTariffSlab> tariffSlabs;
  final List<Reading> readings;
  final MeterBaselineAnchor? baselineAnchor;
  final Reading? reading;

  const _ReadingFormSheet({
    required this.meter,
    required this.tariffSlabs,
    required this.readings,
    this.baselineAnchor,
    this.reading,
  });

  @override
  State<_ReadingFormSheet> createState() => _ReadingFormSheetState();
}

class _ReadingFormSheetState extends State<_ReadingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _billController;
  late final TextEditingController _noteController;
  late DateTime _date;
  late String _readingKind;
  late bool _showMoreOptions;

  @override
  void initState() {
    super.initState();
    final reading = widget.reading;
    _valueController = TextEditingController(
      text: reading == null ? '' : _formatNumber(reading.value),
    );
    _billController = TextEditingController(
      text: reading?.billAmount == null
          ? ''
          : _formatNumber(reading!.billAmount!),
    );
    _noteController = TextEditingController(text: reading?.note ?? '');
    _date = reading?.date ?? DateTime.now();
    _readingKind = reading?.readingKind ?? 'normal';
    // Keep the add flow intentionally compact. Existing readings open with
    // their complete data visible so editing behavior remains unchanged.
    _showMoreOptions = reading != null;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _billController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final editing = widget.reading != null;
    final value = _parseDouble(_valueController.text);
    final calculation = _calculate(value);
    final usage = calculation.usage;
    final estimate = calculation.estimate;

    return Container(
      decoration: BoxDecoration(
        color: neutral.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        18 + MediaQuery.viewInsetsOf(context).bottom,
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
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: neutral.divider,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Color(widget.meter.colorValue).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      MeterCatalog.iconFor(widget.meter.iconKey),
                      color: Color(widget.meter.colorValue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editing ? 'Edit reading' : 'Add reading',
                          style: TextStyle(
                            color: neutral.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.meter.name,
                          style: TextStyle(color: neutral.textSecondary),
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
              const SizedBox(height: 20),
              TextFormField(
                controller: _valueController,
                autofocus: !editing,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (text) {
                  final parsed = _parseDouble(text ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Enter a valid reading';
                  }
                  return null;
                },
                decoration: _decoration(
                  label: 'Current reading (${widget.meter.unitLabel})',
                  icon: Icons.speed_rounded,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickDateAndTime,
                child: InputDecorator(
                  decoration: _decoration(
                    label: 'Reading date and time',
                    icon: Icons.event_rounded,
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(_date),
                    style: TextStyle(color: neutral.textPrimary),
                  ),
                ),
              ),
              if (!editing) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                      () => _showMoreOptions = !_showMoreOptions,
                    ),
                    icon: Icon(
                      _showMoreOptions
                          ? Icons.expand_less_rounded
                          : Icons.tune_rounded,
                      size: 19,
                    ),
                    label: Text(
                      _showMoreOptions ? 'Show less' : 'More options',
                    ),
                  ),
                ),
              ],
              if (_showMoreOptions) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _readingKind,
                  decoration: _decoration(
                    label: 'Reading type',
                    icon: Icons.fact_check_outlined,
                  ),
                  items: MeterCatalog.readingKinds.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _readingKind = value);
                  },
                ),
                if (calculation.next != null) ...[
                  const SizedBox(height: 10),
                  _InfoBanner(
                    icon: Icons.history_rounded,
                    text:
                        'This reading will be inserted by date before ${DateFormat('dd MMM yyyy, hh:mm a').format(calculation.next!.date)}. The surrounding usage intervals will be recalculated automatically.',
                    color: AppColors.primary,
                  ),
                ],
                if (calculation.isOutOfSequence) ...[
                  const SizedBox(height: 10),
                  _InfoBanner(
                    icon: Icons.info_outline_rounded,
                    text:
                        'The value does not follow the surrounding meter values, but it will still be saved at the selected date. Choose meter reset only when the physical meter was actually reset or replaced.',
                    color: AppColors.warning,
                  ),
                ],
                if (_readingKind == 'meter_reset') ...[
                  const SizedBox(height: 10),
                  _InfoBanner(
                    icon: Icons.restart_alt_rounded,
                    text:
                        'Meter reset is optional and should only be used when the physical meter restarted from a lower value.',
                    color: AppColors.warning,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _billController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _decoration(
                    label: 'Actual bill amount (PKR, optional)',
                    icon: Icons.receipt_long_outlined,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: _decoration(
                    label: 'Note (optional)',
                    icon: Icons.notes_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: neutral.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: neutral.divider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _PreviewMetric(
                          label: 'Usage since previous',
                          value:
                              '${NumberFormat('#,##0.##').format(usage)} ${widget.meter.unitLabel}',
                        ),
                      ),
                      Container(width: 1, height: 38, color: neutral.divider),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: _PreviewMetric(
                            label: 'Estimated bill cost',
                            value:
                                'PKR ${NumberFormat('#,##0.##').format(estimate)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
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
                  label: Text(editing ? 'Save reading' : 'Add reading'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.themeColors.neutral.divider),
      ),
    );
  }

  Future<void> _pickDateAndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;

    setState(() {
      _date = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _date.hour,
        time?.minute ?? _date.minute,
      );
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final value = _parseDouble(_valueController.text)!;
    final calculation = _calculate(value);
    final estimate = calculation.estimate;
    final existing = widget.reading;
    final now = DateTime.now();

    Navigator.pop(
      context,
      Reading(
        id: existing?.id,
        value: value,
        date: _date,
        meterId: widget.meter.id!,
        note: _noteController.text.trim(),
        billAmount: _parseDouble(_billController.text),
        estimatedCost: estimate,
        source: _readingKind == 'estimated' ? 'estimated' : 'manual',
        readingKind: _readingKind,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  _ReadingCalculation _calculate(double? value) {
    final neighbors = meterReadingNeighbors(
      readings: widget.readings,
      date: _date,
      excludingReadingId: widget.reading?.id,
    );
    final baselineDate = meterBaselineDate(
      widget.meter,
      widget.readings,
      baselineAnchor: widget.baselineAnchor,
    );
    final editingBaseline = widget.reading != null &&
        isMeterBaselineReading(
          widget.meter,
          widget.readings,
          widget.reading!,
          baselineAnchor: widget.baselineAnchor,
        );

    double? previousValue = neighbors.previous?.value;
    if (editingBaseline) {
      previousValue = widget.meter.baseline;
    } else if (widget.meter.baseline != null &&
        baselineDate != null &&
        !_date.isBefore(baselineDate) &&
        (neighbors.previous == null ||
            neighbors.previous!.date.isBefore(baselineDate))) {
      previousValue = widget.meter.baseline;
    }

    final difference = value == null || previousValue == null
        ? 0.0
        : value - previousValue;
    final usage = difference < 0 ? 0.0 : difference;
    final inCurrentCycle = baselineDate == null || !_date.isBefore(baselineDate);
    final billingUsage = value == null ||
            widget.meter.baseline == null ||
            !inCurrentCycle
        ? 0.0
        : (value - widget.meter.baseline!)
            .clamp(0, double.infinity)
            .toDouble();
    final estimate = !inCurrentCycle
        ? 0.0
        : MeterInsights.calculateCost(
            units: billingUsage,
            meter: widget.meter,
            slabs: widget.tariffSlabs,
          );
    final isOutOfSequence = value != null &&
        ((previousValue != null && value < previousValue) ||
            (neighbors.next != null && value > neighbors.next!.value));

    return _ReadingCalculation(
      previous: neighbors.previous,
      next: neighbors.next,
      usage: usage,
      estimate: estimate,
      isOutOfSequence: isOutOfSequence,
    );
  }

  static double? _parseDouble(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}

class _ReadingCalculation {
  final Reading? previous;
  final Reading? next;
  final double usage;
  final double estimate;
  final bool isOutOfSequence;

  const _ReadingCalculation({
    required this.previous,
    required this.next,
    required this.usage,
    required this.estimate,
    required this.isOutOfSequence,
  });
}

class _PreviewMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: neutral.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: neutral.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.themeColors.neutral.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Retained so older code that embeds the original compact reader still builds.
class AddReadingWidget extends StatefulWidget {
  final Function(int reading, DateTime dateTime) onAddReading;

  const AddReadingWidget({
    required this.onAddReading,
    super.key,
  });

  @override
  State<AddReadingWidget> createState() => _AddReadingWidgetState();
}

