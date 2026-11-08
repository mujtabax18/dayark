import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_x.dart';
import '../../../../models/meter.dart';

Future<List<MeterTariffSlab>?> showTariffSetupSheet({
  required BuildContext context,
  required Meter meter,
  required List<MeterTariffSlab> slabs,
}) {
  return showModalBottomSheet<List<MeterTariffSlab>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TariffSetupSheet(meter: meter, slabs: slabs),
  );
}

class _TariffSetupSheet extends StatefulWidget {
  final Meter meter;
  final List<MeterTariffSlab> slabs;

  const _TariffSetupSheet({required this.meter, required this.slabs});

  @override
  State<_TariffSetupSheet> createState() => _TariffSetupSheetState();
}

class _TariffSetupSheetState extends State<_TariffSetupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<_EditableSlab> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.slabs.isEmpty
        ? [
            _EditableSlab(
              from: 0,
              to: null,
              rate: widget.meter.unitRate,
              label: 'Default',
            ),
          ]
        : widget.slabs
            .map(
              (slab) => _EditableSlab(
                from: slab.fromUnit,
                to: slab.toUnit,
                rate: slab.rate,
                label: slab.label,
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.88,
      decoration: BoxDecoration(
        color: neutral.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
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
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.price_change_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tariff slabs',
                        style: TextStyle(
                          color: neutral.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Configure your current provider rates manually',
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
                  icon: const Icon(Icons.close_rounded),
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pakistan utility tariffs can change. Enter the slabs shown on your latest bill. The final open-ended slab should leave “To” blank.',
                            style: TextStyle(
                              color: neutral.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_rows.length, (index) {
                    return _SlabCard(
                      index: index,
                      row: _rows[index],
                      canDelete: _rows.length > 1,
                      onDelete: () {
                        final removed = _rows.removeAt(index);
                        removed.dispose();
                        setState(() {});
                      },
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: _addSlab,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add slab'),
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
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, <MeterTariffSlab>[]),
                    child: const Text('Use simple rate'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save slabs'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSlab() {
    final last = _rows.last;
    final nextFrom = _parse(last.toController.text) ??
        _parse(last.fromController.text) ??
        0;
    setState(() {
      _rows.add(
        _EditableSlab(
          from: nextFrom,
          to: null,
          rate: 0,
          label: 'Slab ${_rows.length + 1}',
        ),
      );
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final meterId = widget.meter.id!;
    final slabs = _rows.asMap().entries.map((entry) {
      final row = entry.value;
      return MeterTariffSlab(
        meterId: meterId,
        fromUnit: _parse(row.fromController.text) ?? 0,
        toUnit: _parse(row.toController.text),
        rate: _parse(row.rateController.text) ?? 0,
        label: row.labelController.text.trim(),
        position: entry.key,
      );
    }).toList()
      ..sort((a, b) => a.fromUnit.compareTo(b.fromUnit));

    for (var i = 0; i < slabs.length - 1; i++) {
      final current = slabs[i];
      final next = slabs[i + 1];
      if (current.toUnit == null || current.toUnit! > next.fromUnit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Slabs overlap or an open-ended slab appears before the last row.',
            ),
          ),
        );
        return;
      }
    }

    Navigator.pop(context, slabs);
  }

  static double? _parse(String value) {
    final normalized = value.trim().replaceAll(',', '');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }
}

class _SlabCard extends StatelessWidget {
  final int index;
  final _EditableSlab row;
  final bool canDelete;
  final VoidCallback onDelete;

  const _SlabCard({
    required this.index,
    required this.row,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: neutral.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Slab ${index + 1}',
                style: TextStyle(
                  color: neutral.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppColors.danger,
                  tooltip: 'Remove slab',
                ),
            ],
          ),
          TextFormField(
            controller: row.labelController,
            decoration: _decoration(context, 'Label', Icons.label_outline),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.fromController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final parsed = _TariffSetupSheetState._parse(value ?? '');
                    return parsed == null || parsed < 0
                        ? 'Invalid start'
                        : null;
                  },
                  decoration:
                      _decoration(context, 'From unit', Icons.first_page_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: row.toController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final to = _TariffSetupSheetState._parse(value ?? '');
                    final from = _TariffSetupSheetState._parse(
                      row.fromController.text,
                    );
                    if (to != null && from != null && to <= from) {
                      return 'Must exceed From';
                    }
                    return null;
                  },
                  decoration:
                      _decoration(context, 'To (blank = ∞)', Icons.last_page_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: row.rateController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final parsed = _TariffSetupSheetState._parse(value ?? '');
              return parsed == null || parsed < 0 ? 'Enter a valid rate' : null;
            },
            decoration: _decoration(
              context,
              'Rate per unit (PKR)',
              Icons.payments_outlined,
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _decoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 19),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.themeColors.neutral.divider),
      ),
      isDense: true,
    );
  }
}

class _EditableSlab {
  final TextEditingController fromController;
  final TextEditingController toController;
  final TextEditingController rateController;
  final TextEditingController labelController;

  _EditableSlab({
    required double from,
    required double? to,
    required double rate,
    required String label,
  })  : fromController = TextEditingController(text: _format(from)),
        toController = TextEditingController(
          text: to == null ? '' : _format(to),
        ),
        rateController = TextEditingController(text: _format(rate)),
        labelController = TextEditingController(text: label);

  void dispose() {
    fromController.dispose();
    toController.dispose();
    rateController.dispose();
    labelController.dispose();
  }

  static String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}
