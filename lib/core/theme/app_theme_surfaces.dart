import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'app_theme_palette.dart';

AppBarThemeData buildAppBarTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return AppBarThemeData(
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    backgroundColor: palette.neutral.background,
    foregroundColor: palette.neutral.textPrimary,
    surfaceTintColor: Colors.transparent,
    titleTextStyle: textTheme.titleLarge,
    iconTheme: IconThemeData(color: palette.neutral.textPrimary),
    actionsIconTheme: IconThemeData(color: palette.neutral.textPrimary),
  );
}

CardThemeData buildAppCardTheme(AppThemePalette palette) {
  return CardThemeData(
    color: palette.neutral.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.large,
      side: BorderSide(color: palette.scheme.outlineVariant),
    ),
  );
}

DialogThemeData buildAppDialogTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return DialogThemeData(
    backgroundColor: palette.scheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    titleTextStyle: textTheme.titleLarge,
    contentTextStyle: textTheme.bodyMedium?.copyWith(
      color: palette.neutral.textSecondary,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.extraLarge,
      side: BorderSide(color: palette.scheme.outlineVariant),
    ),
  );
}

BottomSheetThemeData buildAppBottomSheetTheme(AppThemePalette palette) {
  return BottomSheetThemeData(
    backgroundColor: palette.neutral.card,
    modalBackgroundColor: palette.neutral.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    modalElevation: 0,
    showDragHandle: true,
    dragHandleColor: palette.scheme.outline,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
  );
}

PopupMenuThemeData buildAppPopupMenuTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return PopupMenuThemeData(
    color: palette.scheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    elevation: 3,
    textStyle: textTheme.bodyMedium,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.medium,
      side: BorderSide(color: palette.scheme.outlineVariant),
    ),
  );
}

SnackBarThemeData buildAppSnackBarTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  return SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    insetPadding: const EdgeInsets.all(AppSpacing.md),
    backgroundColor: scheme.inverseSurface,
    contentTextStyle: textTheme.bodyMedium?.copyWith(
      color: scheme.onInverseSurface,
      fontWeight: FontWeight.w600,
    ),
    actionTextColor: scheme.inversePrimary,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
  );
}

ListTileThemeData buildAppListTileTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return ListTileThemeData(
    iconColor: palette.neutral.textSecondary,
    textColor: palette.neutral.textPrimary,
    titleTextStyle: textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    subtitleTextStyle: textTheme.bodySmall,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xxs,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
  );
}

DividerThemeData buildAppDividerTheme(AppThemePalette palette) {
  return DividerThemeData(
    color: palette.neutral.divider,
    thickness: 1,
    space: 1,
  );
}

DropdownMenuThemeData buildAppDropdownMenuTheme(
  AppThemePalette palette,
  TextTheme textTheme,
  InputDecorationThemeData inputTheme,
) {
  return DropdownMenuThemeData(
    textStyle: textTheme.bodyLarge,
    inputDecorationTheme: inputTheme,
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(
        palette.scheme.surfaceContainerHigh,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(3),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(color: palette.scheme.outlineVariant),
        ),
      ),
    ),
  );
}

MenuThemeData buildAppMenuTheme(AppThemePalette palette) {
  return MenuThemeData(
    style: MenuStyle(
      backgroundColor: WidgetStatePropertyAll(
        palette.scheme.surfaceContainerHigh,
      ),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(color: palette.scheme.outlineVariant),
        ),
      ),
    ),
  );
}

TooltipThemeData buildAppTooltipTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return TooltipThemeData(
    decoration: BoxDecoration(
      color: palette.scheme.inverseSurface,
      borderRadius: AppRadius.small,
    ),
    textStyle: textTheme.bodySmall?.copyWith(
      color: palette.scheme.onInverseSurface,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}

SearchBarThemeData buildAppSearchBarTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return SearchBarThemeData(
    backgroundColor: WidgetStatePropertyAll(
      palette.scheme.surfaceContainerHighest,
    ),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: AppRadius.medium),
    ),
    textStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
    hintStyle: WidgetStatePropertyAll(
      textTheme.bodyLarge?.copyWith(color: palette.neutral.textDisabled),
    ),
  );
}
