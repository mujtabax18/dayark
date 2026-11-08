import 'package:flutter/material.dart';

import 'app_Dark_Neutral_Colors.dart';
import 'app_Light_Neutral_Colors.dart';
import 'app_neutral_colors.dart';
import 'app_theme_composer.dart';
import 'app_theme_palette.dart';
import 'app_theme_typography.dart';
import 'app_theme_preset.dart';

abstract final class AppTheme {
  static ThemeData light([AppThemePreset preset = AppThemePreset.indigo]) =>
      _build(
        brightness: Brightness.light,
        neutral: LightNeutralColors(),
        preset: preset,
      );

  static ThemeData dark([AppThemePreset preset = AppThemePreset.indigo]) =>
      _build(
        brightness: Brightness.dark,
        neutral: DarkNeutralColors(),
        preset: preset,
      );

  static ThemeData _build({
    required Brightness brightness,
    required AppNeutralColors neutral,
    required AppThemePreset preset,
  }) {
    final palette = AppThemePalette.create(
      brightness: brightness,
      neutral: neutral,
      preset: preset,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: palette.scheme,
      scaffoldBackgroundColor: neutral.background,
      canvasColor: neutral.background,
      cardColor: neutral.card,
      dividerColor: neutral.divider,
      disabledColor: neutral.textDisabled,
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[palette.extension],
    );

    final textTheme = buildAppTextTheme(base.textTheme, palette);
    return composeAppTheme(base, palette, textTheme);
  }
}
