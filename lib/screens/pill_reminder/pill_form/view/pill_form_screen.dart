import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/pill_ui_helpers.dart';
import '../../shared/pill_desktop_navigation.dart';
import '../controller/pill_form_controller.dart';
import '../controller/pillformstate.dart';
import '../provider/pill_form_provider.dart';
import '../../../navigation/widgets/desktop_content_frame.dart';
part '../widgets/pill_form_widgets.dart';

class PillFormScreen extends ConsumerStatefulWidget {
  const PillFormScreen({super.key, this.pill});

  final Map<String, dynamic>? pill;

  @override
  ConsumerState<PillFormScreen> createState() => _PillFormScreenState();
}

class _PillFormScreenState extends ConsumerState<PillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final strengthCtrl = TextEditingController();
  final doseQuantityCtrl = TextEditingController(text: '1');
  final notesCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '30');
  final lowInventoryCtrl = TextEditingController(text: '5');
  final intervalCtrl = TextEditingController(text: '10');

  int? pillTypeId;
  int? dosageTypeId;
  String colorHex = '#6C63FF';
  String ruleType = 'DAILY';
  List<TimeOfDay> times = const [TimeOfDay(hour: 8, minute: 0)];
  List<int> selectedDays = [];
  int monthlyDay = DateTime.now().day;
  DateTime startDate = DateTime.now();
  DateTime? endDate;
  bool useEndDate = false;
  bool trackInventory = true;
  bool loadingRule = false;

  static const colors = <String>[
    '#6C63FF',
    '#2563EB',
    '#0EA5E9',
    '#14B8A6',
    '#22C55E',
    '#84CC16',
    '#F59E0B',
    '#F97316',
    '#EF4444',
    '#EC4899',
    '#A855F7',
    '#64748B',
  ];

  @override
  void initState() {
    super.initState();
    final pill = widget.pill;
    if (pill != null) {
      nameCtrl.text = pill['name']?.toString() ?? '';
      strengthCtrl.text = pill['dosage_value']?.toString() ?? '';
      doseQuantityCtrl.text = pill['dose_quantity']?.toString() ?? '1';
      notesCtrl.text = pill['notes']?.toString() ?? '';
      pillTypeId = pill['pill_type_id'] as int?;
      dosageTypeId = pill['dosage_type_id'] as int?;
      colorHex = pill['color_hex']?.toString() ?? '#6C63FF';
      trackInventory = (pill['track_inventory'] as num?)?.toInt() != 0;
      if (pill['start_date'] != null) {
        startDate = DateTime.parse(pill['start_date'] as String);
      }
      if (pill['end_date'] != null) {
        endDate = DateTime.parse(pill['end_date'] as String);
        useEndDate = true;
      }
      _loadEditData(pill['id'] as int);
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    strengthCtrl.dispose();
    doseQuantityCtrl.dispose();
    notesCtrl.dispose();
    quantityCtrl.dispose();
    lowInventoryCtrl.dispose();
    intervalCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEditData(int pillId) async {
    setState(() => loadingRule = true);
    final meta = await ref
        .read(pillFormControllerProvider.notifier)
        .loadEditMeta(pillId);
    final rule = meta?['rule'] as Map<String, dynamic>?;
    final inventory = meta?['inventory'] as Map<String, dynamic>?;

    if (inventory != null) {
      lowInventoryCtrl.text =
          inventory['low_stock_threshold']?.toString() ?? '5';
      quantityCtrl.text = inventory['remaining_quantity']?.toString() ?? '0';
    }
    if (rule != null) {
      ruleType = rule['rule_type']?.toString() ?? 'DAILY';
      intervalCtrl.text = rule['interval_days']?.toString() ?? '10';
      selectedDays = _decodeIntList(rule['days_of_week']);
      final monthDays = _decodeIntList(rule['days_of_month']);
      if (monthDays.isNotEmpty) monthlyDay = monthDays.first;
      try {
        final decodedTimes = List<String>.from(
          jsonDecode(rule['times'] as String),
        );
        times = decodedTimes.map((value) {
          final parts = value.split(':');
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }).toList();
      } catch (_) {
        times = const [TimeOfDay(hour: 8, minute: 0)];
      }
    }
    if (mounted) setState(() => loadingRule = false);
  }

  List<int> _decodeIntList(dynamic value) {
    if (value == null) return [];
    try {
      return List<int>.from(jsonDecode(value.toString()));
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(pillFormControllerProvider);
    final controller = ref.read(pillFormControllerProvider.notifier);
    final desktopNav = PillDesktopNavigationScope.maybeOf(context);

    if (state.pillTypes.isEmpty ||
        state.dosageTypes.isEmpty ||
        loadingRule) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          leading: desktopNav == null
              ? null
              : IconButton(
                  tooltip: 'Back to medicines',
                  onPressed: desktopNav.onCloseDetail,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
          title: Text(widget.pill == null ? 'Add medicine' : 'Edit medicine'),
        ),
        body: DesktopContentFrame(
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    pillTypeId ??= state.pillTypes.first['id'] as int;
    dosageTypeId ??= state.dosageTypes.first['id'] as int;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: desktopNav == null
            ? null
            : IconButton(
                tooltip: 'Back',
                onPressed: desktopNav.onCloseDetail,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: Text(widget.pill == null ? 'Add medicine' : 'Edit medicine'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
          children: [
            _PreviewCard(
              name: nameCtrl.text.trim().isEmpty
                  ? 'Medicine name'
                  : nameCtrl.text.trim(),
              colorHex: colorHex,
              pillTypeName: _selectedTypeName(state),
              dose: doseQuantityCtrl.text.trim().isEmpty
                  ? '1'
                  : doseQuantityCtrl.text.trim(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.medication_outlined,
              title: 'Medicine details',
              subtitle: 'Name the medicine and define each dose.',
              children: [
                _field(
                  nameCtrl,
                  'Medicine name',
                  prefixIcon: Icons.edit_outlined,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const _FieldLabel('Medicine type'),
                _typeSelector(state),
                const SizedBox(height: 18),
                const _FieldLabel('Medicine color'),
                _colorSelector(),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        strengthCtrl,
                        'Strength',
                        number: true,
                        prefixIcon: Icons.science_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _unitSelector(state)),
                  ],
                ),
                _field(
                  doseQuantityCtrl,
                  'Quantity per dose',
                  number: true,
                  prefixIcon: Icons.numbers_rounded,
                  helper: 'Example: 1 tablet or 5 ml',
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                _field(
                  notesCtrl,
                  'Instructions or notes',
                  isRequired: false,
                  maxLines: 3,
                  prefixIcon: Icons.notes_rounded,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.notifications_active_outlined,
              title: 'Reminder plan',
              subtitle: 'Choose when and how often the reminder repeats.',
              children: [
                const _FieldLabel('Repeat'),
                _repeatSelector(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Padding(
                    key: ValueKey(ruleType),
                    padding: const EdgeInsets.only(top: 14),
                    child: _repeatOptions(),
                  ),
                ),
                const SizedBox(height: 16),
                _timeSelector(),
                const SizedBox(height: 8),
                _DateTile(
                  title: 'Start date',
                  subtitle: 'Reminders begin on this date',
                  date: startDate,
                  onTap: _pickStartDate,
                ),
                const SizedBox(height: 10),
                _ToggleTile(
                  icon: Icons.event_busy_outlined,
                  title: 'Set an end date',
                  subtitle: 'Stop reminders automatically',
                  value: useEndDate,
                  onChanged: (value) => setState(() {
                    useEndDate = value;
                    endDate ??= startDate.add(const Duration(days: 30));
                  }),
                ),
                if (useEndDate) ...[
                  const SizedBox(height: 10),
                  _DateTile(
                    title: 'End date',
                    subtitle: 'Last active reminder date',
                    date: endDate!,
                    onTap: _pickEndDate,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              icon: Icons.inventory_2_outlined,
              title: 'Stock alerts',
              subtitle: 'Track remaining medicine and get a refill warning.',
              children: [
                _ToggleTile(
                  icon: Icons.inventory_outlined,
                  title: 'Track medicine stock',
                  subtitle: 'Reduce stock automatically after each dose',
                  value: trackInventory,
                  onChanged: (value) =>
                      setState(() => trackInventory = value),
                ),
                if (trackInventory) ...[
                  const SizedBox(height: 14),
                  if (widget.pill == null)
                    _field(
                      quantityCtrl,
                      'Starting stock',
                      number: true,
                      prefixIcon: Icons.add_box_outlined,
                      textInputAction: TextInputAction.next,
                    ),
                  _field(
                    lowInventoryCtrl,
                    'Low-stock alert level',
                    number: true,
                    prefixIcon: Icons.warning_amber_rounded,
                    helper: 'You will be warned at or below this quantity',
                    textInputAction: TextInputAction.done,
                  ),
                  if (widget.pill != null)
                    _InfoNote(
                      icon: Icons.info_outline_rounded,
                      text:
                          'Use Refill from My Medicines to add more stock.',
                      color: scheme.primary,
                    ),
                ],
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              _InfoNote(
                icon: Icons.error_outline_rounded,
                text: state.error!,
                color: scheme.error,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Material(
        color: scheme.surface,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: state.isSaving ? null : () => _save(controller),
              icon: state.isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(
                widget.pill == null ? 'Add medicine' : 'Save changes',
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _selectedTypeName(PillFormState state) {
    return state.pillTypes
        .firstWhere(
          (item) => item['id'] == pillTypeId,
          orElse: () => state.pillTypes.first,
        )['name']
        .toString();
  }

  Widget _typeSelector(PillFormState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: state.pillTypes.map((item) {
        final selected = pillTypeId == item['id'];
        return ChoiceChip(
          avatar: Icon(PillUi.iconForType(item['name']), size: 18),
          label: Text(item['name'].toString()),
          selected: selected,
          onSelected: (_) => setState(() => pillTypeId = item['id'] as int),
        );
      }).toList(),
    );
  }

  Widget _colorSelector() {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((hex) {
        final color = PillUi.colorFromHex(hex);
        final selected = colorHex == hex;
        return Semantics(
          label: 'Select medicine color $hex',
          selected: selected,
          button: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => colorHex = hex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.onSurface : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: PillUi.readableOn(color),
                        size: 20,
                      )
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _unitSelector(PillFormState state) {
    return DropdownButtonFormField<int>(
      value: dosageTypeId,
      decoration: const InputDecoration(
        labelText: 'Unit',
        prefixIcon: Icon(Icons.straighten_rounded),
      ),
      items: state.dosageTypes
          .map(
            (item) => DropdownMenuItem<int>(
              value: item['id'] as int,
              child: Text(item['name'].toString()),
            ),
          )
          .toList(),
      onChanged: (value) => setState(() => dosageTypeId = value),
      validator: (value) => value == null ? 'Required' : null,
    );
  }

  Widget _repeatSelector() {
    const options = <(String, String, IconData)>[
      ('ONCE', 'Once', Icons.looks_one_outlined),
      ('DAILY', 'Daily', Icons.today_outlined),
      ('WEEKLY', 'Weekly', Icons.date_range_outlined),
      ('MONTHLY', 'Monthly', Icons.calendar_month_outlined),
      ('INTERVAL', 'Custom', Icons.repeat_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(option.$3, size: 17),
              label: Text(option.$2),
              selected: ruleType == option.$1,
              onSelected: (_) => setState(() => ruleType = option.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _repeatOptions() {
    if (ruleType == 'WEEKLY') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Days of the week'),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: List.generate(7, (index) {
              final day = index + 1;
              return FilterChip(
                label: Text(
                  const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                ),
                selected: selectedDays.contains(day),
                onSelected: (selected) => setState(() {
                  selected
                      ? selectedDays.add(day)
                      : selectedDays.remove(day);
                  selectedDays.sort();
                }),
              );
            }),
          ),
        ],
      );
    }

    if (ruleType == 'MONTHLY') {
      return DropdownButtonFormField<int>(
        value: monthlyDay.clamp(1, 31).toInt(),
        decoration: const InputDecoration(
          labelText: 'Day of each month',
          prefixIcon: Icon(Icons.calendar_today_outlined),
        ),
        items: List.generate(
          31,
          (index) => DropdownMenuItem(
            value: index + 1,
            child: Text('Day ${index + 1}'),
          ),
        ),
        onChanged: (value) => setState(() => monthlyDay = value ?? 1),
      );
    }

    if (ruleType == 'INTERVAL') {
      return _field(
        intervalCtrl,
        'Repeat every number of days',
        number: true,
        prefixIcon: Icons.repeat_rounded,
        helper: 'Example: enter 10 for every 10 days',
      );
    }

    if (ruleType == 'ONCE') {
      return _InfoNote(
        icon: Icons.info_outline_rounded,
        text: 'This reminder will run only once on the selected start date.',
        color: Theme.of(context).colorScheme.primary,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _timeSelector() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _FieldLabel('Reminder times')),
            TextButton.icon(
              onPressed: _addTime,
              icon: const Icon(Icons.add_alarm_outlined, size: 19),
              label: const Text('Add time'),
            ),
          ],
        ),
        if (times.isEmpty)
          _InfoNote(
            icon: Icons.schedule_rounded,
            text: 'Add at least one reminder time.',
            color: scheme.error,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: times.asMap().entries.map((entry) {
              final time = entry.value;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _editTime(entry.key),
                  child: Ink(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    decoration: BoxDecoration(
                      color: PillUi.subtleSurface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(.8),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          time.format(context),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: 'Remove time',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: const Icon(Icons.close_rounded, size: 17),
                          onPressed: () => setState(
                            () => times = [...times]..removeAt(entry.key),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _addTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (value == null) return;
    setState(() {
      times = [...times, value]
        ..sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(
            b.hour * 60 + b.minute,
          ),
        );
    });
  }

  Future<void> _editTime(int index) async {
    final value = await showTimePicker(
      context: context,
      initialTime: times[index],
    );
    if (value == null) return;
    setState(() {
      final updated = [...times];
      updated[index] = value;
      updated.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(
          b.hour * 60 + b.minute,
        ),
      );
      times = updated;
    });
  }

  Future<void> _pickStartDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value == null) return;
    setState(() {
      startDate = value;
      monthlyDay = value.day;
      if (endDate != null && endDate!.isBefore(value)) endDate = value;
    });
  }

  Future<void> _pickEndDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate,
      firstDate: startDate,
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => endDate = value);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool isRequired = true,
    int maxLines = 1,
    String? helper,
    IconData? prefixIcon,
    TextInputAction? textInputAction,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : maxLines > 1
                ? TextInputType.multiline
                : TextInputType.text,
        textInputAction: textInputAction ??
            (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          alignLabelWithHint: maxLines > 1,
        ),
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'Required';
          }
          if (number && value != null && value.isNotEmpty) {
            final parsed = double.tryParse(value);
            if (parsed == null || parsed <= 0) {
              return 'Enter a number above zero';
            }
          }
          return null;
        },
      ),
    );
  }

  Future<void> _save(PillFormController controller) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (times.isEmpty) return _message('Add at least one reminder time');
    if (ruleType == 'WEEKLY' && selectedDays.isEmpty) {
      return _message('Select at least one weekday');
    }

    final timeStrings = times
        .map(
          (time) =>
              '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}',
        )
        .toList();
    final end = useEndDate && endDate != null
        ? PillUi.dateKey(endDate!)
        : null;

    try {
      if (widget.pill == null) {
        await controller.addPill(
          name: nameCtrl.text.trim(),
          dosageValue: double.parse(strengthCtrl.text),
          doseQuantity: double.parse(doseQuantityCtrl.text),
          dosageTypeId: dosageTypeId!,
          pillTypeId: pillTypeId!,
          colorHex: colorHex,
          notes: notesCtrl.text.trim(),
          startDate: PillUi.dateKey(startDate),
          endDate: end,
          trackInventory: trackInventory,
          initialQuantity:
              trackInventory ? double.parse(quantityCtrl.text) : 0,
          lowInventoryAlertAt: int.tryParse(lowInventoryCtrl.text) ?? 5,
          ruleType: ruleType,
          times: timeStrings,
          daysOfWeek: ruleType == 'WEEKLY' ? selectedDays : null,
          daysOfMonth: ruleType == 'MONTHLY' ? [monthlyDay] : null,
          intervalDays:
              ruleType == 'INTERVAL' ? int.tryParse(intervalCtrl.text) : null,
        );
      } else {
        await controller.updatePill(
          pillId: widget.pill!['id'] as int,
          name: nameCtrl.text.trim(),
          dosageValue: double.parse(strengthCtrl.text),
          doseQuantity: double.parse(doseQuantityCtrl.text),
          dosageTypeId: dosageTypeId!,
          pillTypeId: pillTypeId!,
          colorHex: colorHex,
          notes: notesCtrl.text.trim(),
          startDate: PillUi.dateKey(startDate),
          endDate: end,
          trackInventory: trackInventory,
          lowInventoryAlertAt: int.tryParse(lowInventoryCtrl.text) ?? 5,
          ruleType: ruleType,
          times: timeStrings,
          daysOfWeek: ruleType == 'WEEKLY' ? selectedDays : null,
          daysOfMonth: ruleType == 'MONTHLY' ? [monthlyDay] : null,
          intervalDays:
              ruleType == 'INTERVAL' ? int.tryParse(intervalCtrl.text) : null,
        );
      }
      if (mounted) {
        final desktopNav = PillDesktopNavigationScope.maybeOf(context);
        if (desktopNav != null) {
          desktopNav.onCloseDetail();
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _message(String value) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(value),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

