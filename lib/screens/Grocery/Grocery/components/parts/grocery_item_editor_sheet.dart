part of '../AddGroceryItemWidget.dart';

class GroceryItemEditorSheet extends ConsumerStatefulWidget {
  const GroceryItemEditorSheet({
    super.key,
    required this.groceryId,
    this.item,
  });

  final int groceryId;
  final Map<String, dynamic>? item;

  @override
  ConsumerState<GroceryItemEditorSheet> createState() =>
      _GroceryItemEditorSheetState();
}

class _GroceryItemEditorSheetState
    extends ConsumerState<GroceryItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  late String _itemType;
  late String _unit;
  late String _priority;
  late bool _hasDueDate;
  late DateTime _dueDate;
  late TimeOfDay _dueTime;
  late bool _alertEnabled;
  late int _alertMinutesBefore;
  bool _saving = false;

  bool get _isEditing => widget.item != null;

  static const _types = <String, String>{
    'general': 'General',
    'food': 'Food',
    'fruit_veg': 'Fruit & vegetables',
    'dairy': 'Dairy',
    'meat': 'Meat',
    'bakery': 'Bakery',
    'drinks': 'Drinks',
    'cleaning': 'Cleaning',
    'personal_care': 'Personal care',
    'household': 'Household supplies',
  };

  static const _units = <String>[
    'item',
    'pack',
    'box',
    'bottle',
    'kg',
    'g',
    'litre',
    'ml',
    'dozen',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?['name']?.toString() ?? '');
    _quantityController = TextEditingController(
      text: _formatQuantity((item?['quantity'] as num?)?.toDouble() ?? 1),
    );
    _notesController = TextEditingController(text: item?['notes']?.toString() ?? '');
    _itemType = item?['item_type']?.toString() ?? 'general';
    _unit = item?['unit']?.toString() ?? 'item';
    _priority = item?['priority']?.toString() ?? 'normal';
    final dueAt = GroceryCatalog.dateTimeFrom(item?['due_at']);
    _hasDueDate = dueAt != null;
    _dueDate = dueAt ?? DateTime.now();
    _dueTime = dueAt == null
        ? const TimeOfDay(hour: 18, minute: 0)
        : TimeOfDay.fromDateTime(dueAt);
    _alertEnabled = GroceryCatalog.boolFrom(item?['alert_enabled']);
    _alertMinutesBefore = (item?['alert_minutes_before'] as num?)?.toInt() ?? 60;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
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
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: _dueTime);
    if (time != null) setState(() => _dueTime = time);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final quantity = double.tryParse(_quantityController.text.trim()) ?? 1;
    setState(() => _saving = true);
    try {
      final service = ref.read(dbServiceProvider);
      if (_isEditing) {
        await service.updateGroceryItem(
          id: widget.item!['id'] as int,
          groceryId: widget.groceryId,
          name: _nameController.text,
          itemType: _itemType,
          quantity: quantity,
          unit: _unit,
          notes: _notesController.text,
          priority: _priority,
          dueAt: _dueAt,
          alertEnabled: _alertEnabled && _hasDueDate,
          alertMinutesBefore: _alertMinutesBefore,
        );
      } else {
        await service.createGroceryItem(
          groceryId: widget.groceryId,
          name: _nameController.text,
          itemType: _itemType,
          quantity: quantity,
          unit: _unit,
          notes: _notesController.text,
          priority: _priority,
          dueAt: _dueAt,
          alertEnabled: _alertEnabled && _hasDueDate,
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final accent = Theme.of(context).colorScheme.primary;

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
                Text(
                  _isEditing ? 'Edit grocery item' : 'Add grocery item',
                  style: TextStyle(
                    color: neutral.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add quantity, type, priority, due time, and an alert.',
                  style: TextStyle(color: neutral.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    context,
                    label: 'Item name',
                    hint: 'Rice, milk, detergent...',
                    icon: FontAwesomeIcons.basketShopping,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an item name'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _itemType,
                  decoration: _inputDecoration(
                    context,
                    label: 'Item type',
                    icon: FontAwesomeIcons.tags,
                  ),
                  items: _types.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _itemType = value ?? 'general'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration(
                          context,
                          label: 'Quantity',
                          icon: FontAwesomeIcons.hashtag,
                        ),
                        validator: (value) {
                          final number = double.tryParse(value?.trim() ?? '');
                          return number == null || number <= 0
                              ? 'Invalid quantity'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _units.contains(_unit) ? _unit : 'item',
                        decoration: _inputDecoration(
                          context,
                          label: 'Unit',
                          icon: FontAwesomeIcons.scaleBalanced,
                        ),
                        items: _units
                            .map((unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _unit = value ?? 'item'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: _inputDecoration(
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    context,
                    label: 'Notes',
                    hint: 'Brand, shop, size, budget...',
                    icon: FontAwesomeIcons.noteSticky,
                  ),
                ),
                const SizedBox(height: 14),
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
                    secondary: CenteredFaIcon(FontAwesomeIcons.calendarCheck, color: accent, size: 18),
                    title: Text('Set due date and time', style: TextStyle(color: neutral.textPrimary, fontWeight: FontWeight.w700)),
                    subtitle: Text('Track late purchases and completion delay.', style: TextStyle(color: neutral.textSecondary, fontSize: 12)),
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
                      subtitle: Text('Show this item in the household alert center.', style: TextStyle(color: neutral.textSecondary, fontSize: 12)),
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
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save changes' : 'Add item'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatQuantity(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
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
