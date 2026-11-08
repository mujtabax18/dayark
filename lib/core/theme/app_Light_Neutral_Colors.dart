import 'package:flutter/material.dart';

import 'app_neutral_colors.dart';

class LightNeutralColors implements AppNeutralColors {
  @override
  Color get background => const Color(0xFFF6F7FB);

  @override
  Color get section => const Color(0xFFF0F2F7);

  @override
  Color get card => const Color(0xFFFFFFFF);

  @override
  Color get divider => const Color(0xFFE2E5EC);

  @override
  Color get textPrimary => const Color(0xFF171A21);

  @override
  Color get textSecondary => const Color(0xFF5E6472);

  @override
  Color get textDisabled => const Color(0xFF979DAA);

  @override
  Color get textPrimaryNot => const Color(0xFFFFFFFF);
}
