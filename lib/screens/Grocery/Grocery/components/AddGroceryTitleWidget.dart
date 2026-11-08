import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_x.dart';
import '../controller/grocery_controller.dart';
import '../shared/grocery_catalog.dart';
import '../../../../core/widgets/common/centered_fa_icon.dart';

class AddGroceryTitleWidget extends ConsumerWidget {
  const AddGroceryTitleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: FilledButton.icon(
          onPressed: () => showGroceryPlanEditor(context, ref),
          icon: const CenteredFaIcon(FontAwesomeIcons.plus, size: 16),
          label: const Text('Create grocery plan'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showGroceryPlanEditor(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? plan,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GroceryPlanEditorSheet(plan: plan),
  ).then((_) {
    refreshGroceryDashboard(ref, groceryId: plan?['id'] as int?);
  });
}

class GroceryPlanEditorSheet extends ConsumerStatefulWidget {
  const GroceryPlanEditorSheet({super.key, this.plan});

  final Map<String, dynamic>? plan;

  @override
  ConsumerState<GroceryPlanEditorSheet> createState() =>
      _GroceryPlanEditorSheetState();
}

class _GroceryPlanEditorSheetState
    extends ConsumerState<GroceryPlanEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _planDate;
  late TimeOfDay _dueTime;
  late String _planType;
  late String _iconKey;
  late int _colorValue;
  late bool _alertEnabled;
  late int _alertMinutesBefore;
  bool _saving = false;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _titleController = TextEditingController(
      text: plan?['title']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: plan?['description']?.toString() ?? '',
    );
    _planDate = GroceryCatalog.dateTimeFrom(plan?['plan_date']) ?? DateTime.now();
    final dueAt = GroceryCatalog.dateTimeFrom(plan?['due_at']);
    _dueTime = dueAt == null
        ? const TimeOfDay(hour: 20, minute: 0)
        : TimeOfDay.fromDateTime(dueAt);
    _planType = plan?['plan_type']?.toString() ?? 'monthly';
    _iconKey = plan?['icon_key']?.toString() ?? 'basket-shopping';
    _colorValue = (plan?['color_value'] as num?)?.toInt() ?? 0xFF2E7D32;
    _alertEnabled = GroceryCatalog.boolFrom(plan?['alert_enabled']);
    _alertMinutesBefore =
        (plan?['alert_minutes_before'] as num?)?.toInt() ?? 60;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime get _dueAt => DateTime(
        _planDate.year,
        _planDate.month,
        _planDate.day,
        _dueTime.hour,
        _dueTime.minute,
      );

  Future<void> _selectDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _planDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => _planDate = value);
  }

  Future<void> _selectTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );
    if (value != null) setState(() => _dueTime = value);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(dbServiceProvider);
      if (_isEditing) {
        await service.updateGroceryPlan(
          id: widget.plan!['id'] as int,
          title: _titleController.text,
          description: _descriptionController.text,
          planDate: _planDate,
          dueAt: _dueAt,
          planType: _planType,
          iconKey: _iconKey,
          colorValue: _colorValue,
          alertEnabled: _alertEnabled,
          alertMinutesBefore: _alertMinutesBefore,
        );
      } else {
        await service.createGroceryPlan(
          title: _titleController.text,
          description: _descriptionController.text,
          planDate: _planDate,
          dueAt: _dueAt,
          planType: _planType,
          iconKey: _iconKey,
          colorValue: _colorValue,
          alertEnabled: _alertEnabled,
          alertMinutesBefore: _alertMinutesBefore,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final accent = Color(_colorValue);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: neutral.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, keyboard + 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: neutral.divider,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: CenteredFaIcon(
                          GroceryCatalog.iconFor(_iconKey),
                          color: accent,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit grocery plan' : 'New grocery plan',
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Create a dated checklist and track every purchase.',
                            style: TextStyle(
                              color: neutral.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    context,
                    label: 'Plan title',
                    hint: 'July monthly groceries',
                    icon: FontAwesomeIcons.basketShopping,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    context,
                    label: 'Description',
                    hint: 'Main household supplies for this month',
                    icon: FontAwesomeIcons.alignLeft,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _planType,
                  decoration: _inputDecoration(
                    context,
                    label: 'Plan type',
                    icon: FontAwesomeIcons.layerGroup,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly grocery')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly grocery')),
                    DropdownMenuItem(value: 'event', child: Text('Event / special shopping')),
                    DropdownMenuItem(value: 'custom', child: Text('Custom list')),
                  ],
                  onChanged: (value) => setState(() => _planType = value ?? 'monthly'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: FontAwesomeIcons.calendarDays,
                        label: 'Plan date',
                        value: DateFormat('dd MMM yyyy').format(_planDate),
                        onTap: _selectDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerTile(
                        icon: FontAwesomeIcons.clock,
                        label: 'Due time',
                        value: _dueTime.format(context),
                        onTap: _selectTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionLabel(label: 'Choose icon', neutral: neutral),
                const SizedBox(height: 10),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: GroceryCatalog.icons.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 9),
                    itemBuilder: (_, index) {
                      final option = GroceryCatalog.icons[index];
                      final selected = option.key == _iconKey;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _iconKey = option.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 68,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? accent.withOpacity(0.12) : neutral.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? accent : neutral.divider,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CenteredFaIcon(option.icon, size: 18, color: selected ? accent : neutral.textSecondary),
                              const SizedBox(height: 7),
                              Text(
                                option.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? accent : neutral.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                _SectionLabel(label: 'Choose color', neutral: neutral),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: GroceryCatalog.colors.map((value) {
                    final selected = value == _colorValue;
                    final color = Color(value);
                    return InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _colorValue = value),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? neutral.textPrimary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: neutral.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: neutral.divider),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _alertEnabled,
                    onChanged: (value) => setState(() => _alertEnabled = value),
                    secondary: CenteredFaIcon(FontAwesomeIcons.bell, color: accent, size: 18),
                    title: Text('Alert me', style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w700)),
                    subtitle: Text('Show an in-app reminder before this plan is due.', style: TextStyle(color: neutral.textSecondary, fontSize: 12)),
                  ),
                ),
                if (_alertEnabled) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _alertMinutesBefore,
                    decoration: _inputDecoration(
                      context,
                      label: 'Alert before',
                      icon: FontAwesomeIcons.clockRotateLeft,
                    ),
                    items: const [
                      DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                      DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                      DropdownMenuItem(value: 60, child: Text('1 hour before')),
                      DropdownMenuItem(value: 180, child: Text('3 hours before')),
                      DropdownMenuItem(value: 1440, child: Text('1 day before')),
                    ],
                    onChanged: (value) => setState(() => _alertMinutesBefore = value ?? 60),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save changes' : 'Create grocery plan'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  required FaIconData icon,
}) {
  final neutral = context.themeColors.neutral;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Padding(
      padding: const EdgeInsets.all(14),
      child: CenteredFaIcon(icon, size: 17, color: neutral.textSecondary),
    ),
    filled: true,
    fillColor: neutral.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: neutral.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: neutral.divider),
    ),
  );
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Material(
      color: neutral.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: neutral.divider),
          ),
          child: Row(
            children: [
              CenteredFaIcon(icon, size: 17, color: neutral.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: neutral.textSecondary, fontSize: 10)),
                    const SizedBox(height: 2),
                    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: neutral.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.neutral});

  final String label;
  final dynamic neutral;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: neutral.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
