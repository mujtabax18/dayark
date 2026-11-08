import 'package:flutter/material.dart';

import 'app_text_styles.dart';
import 'app_theme_palette.dart';

TextTheme buildAppTextTheme(TextTheme base, AppThemePalette palette) {
  final neutral = palette.neutral;

  return base
      .apply(
        bodyColor: neutral.textPrimary,
        displayColor: neutral.textPrimary,
        decorationColor: neutral.textSecondary,
      )
      .copyWith(
        displaySmall: base.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.7,
        ),
        headlineSmall: base.headlineSmall?.merge(AppTextStyles.pageTitle),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.25,
        ),
        titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
        bodySmall: base.bodySmall?.copyWith(
          height: 1.35,
          color: neutral.textSecondary,
        ),
        labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      );
}
