import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'app_colors.dart';
import 'app_theme_palette.dart';

InputDecorationThemeData buildAppInputTheme(AppThemePalette palette) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;

  OutlineInputBorder border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.medium,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecorationThemeData(
    filled: true,
    fillColor: scheme.surfaceContainerHighest,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 15,
    ),
    prefixIconColor: neutral.textSecondary,
    suffixIconColor: neutral.textSecondary,
    labelStyle: TextStyle(color: neutral.textSecondary),
    floatingLabelStyle: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: TextStyle(color: neutral.textDisabled),
    helperStyle: TextStyle(color: neutral.textSecondary),
    errorStyle: TextStyle(color: scheme.error),
    border: border(Colors.transparent),
    enabledBorder: border(scheme.outlineVariant),
    focusedBorder: border(scheme.primary, width: 1.5),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, width: 1.5),
    disabledBorder: border(scheme.outlineVariant.withOpacity(.55)),
  );
}

FilledButtonThemeData buildAppFilledButtonTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return FilledButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppConstraints.minTapTarget, 50),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      elevation: const WidgetStatePropertyAll(0),
      animationDuration: AppDuration.fast,
    ),
  );
}

ElevatedButtonThemeData buildAppElevatedButtonTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;

  return ElevatedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppConstraints.minTapTarget, 50),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.surfaceContainerHighest;
        }
        return scheme.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return neutral.textDisabled;
        }
        return scheme.onPrimary;
      }),
      animationDuration: AppDuration.fast,
    ),
  );
}

OutlinedButtonThemeData buildAppOutlinedButtonTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;

  return OutlinedButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppConstraints.minTapTarget, 50),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 13),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return neutral.textDisabled;
        }
        return scheme.primary;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        return BorderSide(
          color: states.contains(WidgetState.disabled)
              ? scheme.outlineVariant
              : scheme.primary.withOpacity(.55),
        );
      }),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
      animationDuration: AppDuration.fast,
    ),
  );
}

TextButtonThemeData buildAppTextButtonTheme(TextTheme textTheme) {
  return TextButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(40, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.small),
      ),
      animationDuration: AppDuration.fast,
    ),
  );
}

IconButtonThemeData buildAppIconButtonTheme(AppThemePalette palette) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;

  return IconButtonThemeData(
    style: ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppConstraints.minTapTarget, AppConstraints.minTapTarget),
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return neutral.textDisabled;
        }
        return neutral.textPrimary;
      }),
      overlayColor: WidgetStatePropertyAll(
        scheme.primary.withOpacity(palette.isDark ? .16 : .09),
      ),
      shape: const WidgetStatePropertyAll(CircleBorder()),
    ),
  );
}

FloatingActionButtonThemeData buildAppFabTheme(AppThemePalette palette) {
  final scheme = palette.scheme;
  return FloatingActionButtonThemeData(
    elevation: 0,
    focusElevation: 0,
    hoverElevation: 1,
    highlightElevation: 0,
    backgroundColor: scheme.primary,
    foregroundColor: scheme.onPrimary,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
  );
}

ChipThemeData buildAppChipTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;
  return ChipThemeData(
    backgroundColor: scheme.surfaceContainerHighest,
    selectedColor: scheme.secondaryContainer,
    disabledColor: scheme.surfaceContainerHighest.withOpacity(.45),
    checkmarkColor: scheme.onSecondaryContainer,
    iconTheme: IconThemeData(color: neutral.textSecondary, size: 18),
    labelStyle: textTheme.labelMedium?.copyWith(color: neutral.textPrimary),
    secondaryLabelStyle: textTheme.labelMedium?.copyWith(
      color: scheme.onSecondaryContainer,
      fontWeight: FontWeight.w800,
    ),
    side: BorderSide(color: scheme.outlineVariant),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
  );
}

SwitchThemeData buildAppSwitchTheme(AppThemePalette palette) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;
  return SwitchThemeData(
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return scheme.surfaceContainerHighest;
      }
      if (states.contains(WidgetState.selected)) return scheme.primary;
      return scheme.surfaceContainerHighest;
    }),
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return neutral.textDisabled;
      if (states.contains(WidgetState.selected)) return scheme.onPrimary;
      return neutral.textSecondary;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return Colors.transparent;
      return scheme.outline;
    }),
  );
}

CheckboxThemeData buildAppCheckboxTheme(AppThemePalette palette) {
  final scheme = palette.scheme;
  return CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return scheme.primary;
      return Colors.transparent;
    }),
    checkColor: WidgetStatePropertyAll(scheme.onPrimary),
    side: BorderSide(color: scheme.outline, width: 1.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
  );
}

RadioThemeData buildAppRadioTheme(AppThemePalette palette) {
  return RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) return palette.scheme.primary;
      return palette.neutral.textSecondary;
    }),
  );
}

SegmentedButtonThemeData buildAppSegmentedButtonTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;
  return SegmentedButtonThemeData(
    style: ButtonStyle(
      textStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? scheme.onSecondaryContainer
            : neutral.textSecondary;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? scheme.secondaryContainer
            : Colors.transparent;
      }),
      side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: AppRadius.small),
      ),
    ),
  );
}
