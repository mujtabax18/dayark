import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/theme_x.dart';
import '../controller/grocery_controller.dart';
import '../shared/grocery_catalog.dart';
import '../../../../core/widgets/common/centered_fa_icon.dart';

Future<void> showChoreEditor(
  BuildContext context,
  WidgetRef ref, {
  Map<String, dynamic>? chore,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChoreEditorSheet(chore: chore),
  ).then((_) => refreshGroceryDashboard(ref));
}

class ChoreEditorSheet extends ConsumerStatefulWidget {
  const ChoreEditorSheet({super.key, this.chore});

  final Map<String, dynamic>? chore;

  @override
  ConsumerState<ChoreEditorSheet> createState() => _ChoreEditorSheetState();
}

class _ChoreEditorSheetState extends ConsumerState<ChoreEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _choreType;
  late String _priority;
  late String _iconKey;
  late int _colorValue;
  late bool _hasDueDate;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  late bool _alertEnabled;
  late int _alertMinutesBefore;
  late String _recurrenceType;
  late int _repeatInterval;
  bool _saving = false;

  bool get _isEditing => widget.chore != null;

  static const _types = <String, String>{
    'general': 'General',
    'cleaning': 'Cleaning',
    'laundry': 'Laundry',
    'kitchen': 'Kitchen',
    'maintenance': 'Maintenance',
    'organizing': 'Organizing',
    'bills': 'Bills & admin',
    'family': 'Family task',
  };

  @override
  void initState() {
    super.initState();
    final chore = widget.chore;
    _titleController = TextEditingController(text: chore?['title']?.toString() ?? '');
    _descriptionController = TextEditingController(text: chore?['description']?.toString() ?? '');
    _choreType = chore?['chore_type']?.toString() ?? 'general';
    _priority = chore?['priority']?.toString() ?? 'normal';
    _iconKey = chore?['icon_key']?.toString() ?? 'broom';
    _colorValue = (chore?['color_value'] as num?)?.toInt() ?? 0xFF1565C0;
    final dueAt = GroceryCatalog.dateTimeFrom(chore?['due_at']);
    _hasDueDate = dueAt != null;
    _dueDate = dueAt ?? DateTime.now();
    _dueTime = dueAt == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay.fromDateTime(dueAt);
    _alertEnabled = GroceryCatalog.boolFrom(chore?['alert_enabled']);
    _alertMinutesBefore = (chore?['alert_minutes_before'] as num?)?.toInt() ?? 60;
    _recurrenceType = chore?['recurrence_type']?.toString() ?? 'none';
    _repeatInterval = (chore?['repeat_interval'] as num?)?.toInt() ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  DateTime? get _dueAt {
    if (!_hasDueDate) return null;
    return DateTime(
      _dueDate.year,
      _dueDate.month,
      _dueDate.day,
      _dueTime.hour,
      _dueTime.minute,
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => _dueDate = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _dueTime);
    if (value != null) setState(() => _dueTime = value);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(dbServiceProvider);
      if (_isEditing) {
        await service.updateHouseholdChore(
          id: widget.chore!['id'] as int,
          title: _titleController.text,
          description: _descriptionController.text,
          choreType: _choreType,
          priority: _priority,
          iconKey: _iconKey,
          colorValue: _colorValue,
          dueAt: _dueAt,
          alertEnabled: _alertEnabled && _hasDueDate,
          alertMinutesBefore: _alertMinutesBefore,
          recurrenceType: _recurrenceType,
          repeatInterval: _repeatInterval,
        );
      } else {
        await service.createHouseholdChore(
          title: _titleController.text,
          description: _descriptionController.text,
          choreType: _choreType,
          priority: _priority,
          iconKey: _iconKey,
          colorValue: _colorValue,
          dueAt: _dueAt,
          alertEnabled: _alertEnabled && _hasDueDate,
          alertMinutesBefore: _alertMinutesBefore,
          recurrenceType: _recurrenceType,
          repeatInterval: _repeatInterval,
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final accent = Color(_colorValue);

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
                            _isEditing ? 'Edit household chore' : 'New household chore',
                            style: TextStyle(
                              color: neutral.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Track due time, delays, reminders, and repeating work.',
                            style: TextStyle(color: neutral.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    context,
                    label: 'Chore title',
                    hint: 'Clean kitchen, pay electricity bill...',
                    icon: FontAwesomeIcons.listCheck,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a chore title'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    context,
                    label: 'Description',
                    hint: 'Add instructions or useful details',
                    icon: FontAwesomeIcons.alignLeft,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _choreType,
                        decoration: _decoration(
                          context,
                          label: 'Type',
                          icon: FontAwesomeIcons.tags,
                        ),
                        items: _types.entries
                            .map((entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _choreType = value ?? 'general'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: _decoration(
                          context,
                          label: 'Priority',
                          icon: FontAwesomeIcons.flag,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'normal', child: Text('Normal')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                          DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                        ],
                        onChanged: (value) => setState(() => _priority = value ?? 'normal'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Icon', style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: GroceryCatalog.icons.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final option = GroceryCatalog.icons[index];
                      final selected = option.key == _iconKey;
                      return InkWell(
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => setState(() => _iconKey = option.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 54,
                          decoration: BoxDecoration(
                            color: selected ? accent.withOpacity(0.12) : neutral.card,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: selected ? accent : neutral.divider),
                          ),
                          child: Center(
                            child: CenteredFaIcon(
                              option.icon,
                              color: selected ? accent : neutral.textSecondary,
                              size: 18,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text('Color', style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: GroceryCatalog.colors.map((value) {
                    final selected = value == _colorValue;
                    return InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _colorValue = value),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Color(value),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? neutral.textPrimary : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: selected ? const Icon(Icons.check, color: Colors.white, size: 17) : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: neutral.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: neutral.divider),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _hasDueDate,
                    onChanged: (value) => setState(() {
                      _hasDueDate = value;
                      if (!value) _alertEnabled = false;
                    }),
                    secondary: CenteredFaIcon(FontAwesomeIcons.clock, color: accent, size: 18),
                    title: Text('Set due date and time', style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w700)),
                    subtitle: Text('Late completion will be recorded automatically.', style: TextStyle(color: neutral.textSecondary, fontSize: 12)),
                  ),
                ),
                if (_hasDueDate) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerTile(
                          icon: FontAwesomeIcons.calendarDays,
                          label: 'Due date',
                          value: DateFormat('dd MMM yyyy').format(_dueDate),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerTile(
                          icon: FontAwesomeIcons.clock,
                          label: 'Due time',
                          value: _dueTime.format(context),
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                      subtitle: Text('Show this chore in the alert center before it is due.', style: TextStyle(color: neutral.textSecondary, fontSize: 12)),
                    ),
                  ),
                  if (_alertEnabled) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _alertMinutesBefore,
                      decoration: _decoration(
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
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _recurrenceType,
                  decoration: _decoration(
                    context,
                    label: 'Repeat',
                    icon: FontAwesomeIcons.rotate,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
                    DropdownMenuItem(value: 'daily', child: Text('Daily')),
                    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                  ],
                  onChanged: (value) => setState(() => _recurrenceType = value ?? 'none'),
                ),
                if (_recurrenceType != 'none') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _repeatInterval,
                    decoration: _decoration(
                      context,
                      label: 'Repeat interval',
                      icon: FontAwesomeIcons.hashtag,
                    ),
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('Every ${index + 1} ${_intervalLabel(index + 1)}'),
                      ),
                    ),
                    onChanged: (value) => setState(() => _repeatInterval = value ?? 1),
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
                      : Text(_isEditing ? 'Save changes' : 'Create chore'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _intervalLabel(int value) {
    final unit = switch (_recurrenceType) {
      'daily' => 'day',
      'weekly' => 'week',
      'monthly' => 'month',
      _ => 'period',
    };
    return value == 1 ? unit : '${unit}s';
  }
}

InputDecoration _decoration(
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
