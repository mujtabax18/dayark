import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'app_theme_palette.dart';

ProgressIndicatorThemeData buildAppProgressTheme(AppThemePalette palette) {
  return ProgressIndicatorThemeData(
    color: palette.scheme.primary,
    linearTrackColor: palette.scheme.surfaceContainerHighest,
    circularTrackColor: palette.scheme.surfaceContainerHighest,
    linearMinHeight: 7,
  );
}

DatePickerThemeData buildAppDatePickerTheme(AppThemePalette palette) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;
  return DatePickerThemeData(
    backgroundColor: scheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    headerBackgroundColor: scheme.primaryContainer,
    headerForegroundColor: scheme.onPrimaryContainer,
    todayForegroundColor: WidgetStatePropertyAll(scheme.primary),
    todayBorder: BorderSide(color: scheme.primary),
    dayForegroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return scheme.onPrimary;
      if (states.contains(WidgetState.disabled)) return neutral.textDisabled;
      return neutral.textPrimary;
    }),
    dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return scheme.primary;
      return Colors.transparent;
    }),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.extraLarge),
  );
}

TimePickerThemeData buildAppTimePickerTheme(AppThemePalette palette) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;
  return TimePickerThemeData(
    backgroundColor: scheme.surfaceContainerHigh,
    hourMinuteColor: scheme.surfaceContainerHighest,
    hourMinuteTextColor: neutral.textPrimary,
    dayPeriodColor: scheme.surfaceContainerHighest,
    dayPeriodTextColor: neutral.textPrimary,
    dialBackgroundColor: scheme.surfaceContainerHighest,
    dialHandColor: scheme.primary,
    dialTextColor: neutral.textPrimary,
    entryModeIconColor: scheme.primary,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.extraLarge),
  );
}
