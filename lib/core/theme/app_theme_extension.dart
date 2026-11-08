import 'package:flutter/material.dart';

import 'app_neutral_colors.dart';

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({
    required this.neutral,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.onAccent,
    required this.shadow,
    required this.scrim,
  });

  final AppNeutralColors neutral;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color onAccent;
  final Color shadow;
  final Color scrim;

  @override
  AppThemeColors copyWith({
    AppNeutralColors? neutral,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? onAccent,
    Color? shadow,
    Color? scrim,
  }) {
    return AppThemeColors(
      neutral: neutral ?? this.neutral,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      onAccent: onAccent ?? this.onAccent,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppThemeColors lerp(covariant AppThemeColors? other, double t) {
    if (other == null) return this;
    return AppThemeColors(
      neutral: t < .5 ? neutral : other.neutral,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}
