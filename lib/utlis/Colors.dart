import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Backward-compatible aliases for older non-widget code.
/// New UI must read colors from ThemeData instead.
@Deprecated('Use Theme.of(context).colorScheme and AppColors instead.')
abstract final class CColors {
  static const Color primery = AppColors.primary;
  static const Color danger = AppColors.danger;
  static const Color safe = AppColors.success;
  static const Color unSelected = Color(0xFF8B92A1);
}
