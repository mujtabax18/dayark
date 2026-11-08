import 'package:flutter/material.dart';
import '../../../../core/theme/theme_x.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/meter.dart';

class AddMeterWidget extends StatefulWidget {
  final Function(String name, String number) onAddMeter;
  final Meter? meter;

  const AddMeterWidget({
    super.key,
    required this.onAddMeter,
    this.meter,
  });

  @override
  State<AddMeterWidget> createState() => _AddMeterWidgetState();
}

class _AddMeterWidgetState extends State<AddMeterWidget> {
  final nameController = TextEditingController();
  final numberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.meter != null) {
      nameController.text = widget.meter!.name;
      numberController.text = widget.meter!.number;
    }
  }

  void _submit() {
    if (nameController.text.trim().isEmpty) return;

    widget.onAddMeter(
      nameController.text.trim(),
      numberController.text.trim(),
    );

    nameController.clear();
    numberController.clear();
    FocusScope.of(context).unfocus(); // hide keyboard
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        decoration: BoxDecoration(
          color: neutral.card,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Meter Name',
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.electrical_services,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Meter Number (optional)',
                  border: InputBorder.none,
                  prefixIcon:
                      const Icon(Icons.numbers, color: AppColors.warning),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                    ),
                    onPressed: _submit,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    numberController.dispose();
    super.dispose();
  }
}
