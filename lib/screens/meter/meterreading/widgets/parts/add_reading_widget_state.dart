part of '../AddReadingWidget.dart';

class _AddReadingWidgetState extends State<AddReadingWidget> {
  final _controller = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: neutral.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: neutral.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: 'Reading',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.speed_rounded),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
            icon: const Icon(Icons.calendar_today_rounded),
          ),
          IconButton(
            onPressed: _submit,
            icon: const Icon(Icons.check_circle, color: AppColors.success),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 0) return;
    widget.onAddReading(value, _date);
    _controller.clear();
  }
}
