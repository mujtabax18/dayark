import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_neutral_colors.dart';
import 'app_theme_extension.dart';
import 'app_theme_preset.dart';

class AppThemePalette {
  const AppThemePalette({
    required this.brightness,
    required this.neutral,
    required this.scheme,
    required this.extension,
  });

  final Brightness brightness;
  final AppNeutralColors neutral;
  final ColorScheme scheme;
  final AppThemeColors extension;

  bool get isDark => brightness == Brightness.dark;

  factory AppThemePalette.create({
    required Brightness brightness,
    required AppNeutralColors neutral,
    required AppThemePreset preset,
  }) {
    final isDark = brightness == Brightness.dark;
    final seeded = ColorScheme.fromSeed(
      seedColor: preset.primary,
      brightness: brightness,
    );

    final surfaceContainer = Color.alphaBlend(
      neutral.textPrimary.withOpacity(isDark ? .035 : .018),
      neutral.card,
    );
    final surfaceContainerHigh = Color.alphaBlend(
      neutral.textPrimary.withOpacity(isDark ? .065 : .032),
      neutral.card,
    );
    final surfaceContainerHighest = Color.alphaBlend(
      neutral.textPrimary.withOpacity(isDark ? .10 : .052),
      neutral.card,
    );

    final scheme = seeded.copyWith(
      primary: preset.primary,
      secondary: preset.secondary,
      surface: neutral.card,
      onSurface: neutral.textPrimary,
      onSurfaceVariant: neutral.textSecondary,
      outline: neutral.divider,
      outlineVariant: neutral.divider.withOpacity(isDark ? .88 : .78),
      surfaceContainerLowest: neutral.background,
      surfaceContainerLow: neutral.card,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      error: AppColors.danger,
    );

    return AppThemePalette(
      brightness: brightness,
      neutral: neutral,
      scheme: scheme,
      extension: AppThemeColors(
        neutral: neutral,
        success: isDark ? const Color(0xFF4ADE80) : AppColors.success,
        warning: isDark ? const Color(0xFFFBBF24) : AppColors.warning,
        danger: isDark ? const Color(0xFFFB7185) : AppColors.danger,
        info: isDark ? const Color(0xFF38BDF8) : AppColors.info,
        onAccent: Colors.white,
        shadow: isDark ? Colors.black : const Color(0xFF111827),
        scrim: Colors.black,
      ),
    );
  }
}
