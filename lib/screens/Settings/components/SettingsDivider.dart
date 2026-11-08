import 'package:flutter/material.dart';
import '../../../core/theme/theme_x.dart';

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final neutral = context.themeColors.neutral;

    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, color: neutral.divider),
    );
  }
}
