import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'app_theme_palette.dart';

TabBarThemeData buildAppTabBarTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  return TabBarThemeData(
    labelColor: scheme.onPrimaryContainer,
    unselectedLabelColor: palette.neutral.textSecondary,
    dividerColor: Colors.transparent,
    labelStyle: textTheme.labelLarge,
    unselectedLabelStyle: textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
    indicator: BoxDecoration(
      color: scheme.primaryContainer,
      borderRadius: AppRadius.small,
    ),
    indicatorSize: TabBarIndicatorSize.tab,
  );
}

NavigationBarThemeData buildAppNavigationBarTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;
  return NavigationBarThemeData(
    height: 70,
    elevation: 0,
    backgroundColor: neutral.card,
    surfaceTintColor: Colors.transparent,
    indicatorColor: scheme.secondaryContainer,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      return IconThemeData(
        color: states.contains(WidgetState.selected)
            ? scheme.onSecondaryContainer
            : neutral.textSecondary,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      return textTheme.labelSmall?.copyWith(
        color: states.contains(WidgetState.selected)
            ? neutral.textPrimary
            : neutral.textSecondary,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800
            : FontWeight.w600,
      );
    }),
  );
}

BottomNavigationBarThemeData buildAppBottomNavigationBarTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  return BottomNavigationBarThemeData(
    elevation: 0,
    backgroundColor: palette.neutral.card,
    selectedItemColor: palette.scheme.primary,
    unselectedItemColor: palette.neutral.textSecondary,
    selectedLabelStyle: textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w800,
    ),
    unselectedLabelStyle: textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    type: BottomNavigationBarType.fixed,
  );
}

NavigationRailThemeData buildAppNavigationRailTheme(
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  final neutral = palette.neutral;
  return NavigationRailThemeData(
    elevation: 0,
    backgroundColor: neutral.card,
    indicatorColor: scheme.secondaryContainer,
    selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
    unselectedIconTheme: IconThemeData(color: neutral.textSecondary),
    selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
      color: neutral.textPrimary,
    ),
    unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
      color: neutral.textSecondary,
    ),
  );
}

DrawerThemeData buildAppDrawerTheme(AppThemePalette palette) {
  return DrawerThemeData(
    backgroundColor: palette.neutral.card,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(
        right: Radius.circular(AppRadius.xl),
      ),
    ),
  );
}
