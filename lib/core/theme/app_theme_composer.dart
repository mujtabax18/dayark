import 'package:flutter/material.dart';

import 'app_theme_controls.dart';
import 'app_theme_navigation.dart';
import 'app_theme_palette.dart';
import 'app_theme_pickers.dart';
import 'app_theme_surfaces.dart';

ThemeData composeAppTheme(
  ThemeData base,
  AppThemePalette palette,
  TextTheme textTheme,
) {
  final scheme = palette.scheme;
  final inputTheme = buildAppInputTheme(palette);

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    shadowColor: palette.extension.shadow.withOpacity(palette.isDark ? .32 : .09),
    splashColor: scheme.primary.withOpacity(palette.isDark ? .16 : .09),
    highlightColor: scheme.primary.withOpacity(palette.isDark ? .10 : .055),
    focusColor: scheme.primary.withOpacity(.12),
    hoverColor: scheme.primary.withOpacity(.07),
    appBarTheme: buildAppBarTheme(palette, textTheme),
    cardTheme: buildAppCardTheme(palette),
    inputDecorationTheme: inputTheme,
    filledButtonTheme: buildAppFilledButtonTheme(palette, textTheme),
    elevatedButtonTheme: buildAppElevatedButtonTheme(palette, textTheme),
    outlinedButtonTheme: buildAppOutlinedButtonTheme(palette, textTheme),
    textButtonTheme: buildAppTextButtonTheme(textTheme),
    iconButtonTheme: buildAppIconButtonTheme(palette),
    floatingActionButtonTheme: buildAppFabTheme(palette),
    dialogTheme: buildAppDialogTheme(palette, textTheme),
    bottomSheetTheme: buildAppBottomSheetTheme(palette),
    popupMenuTheme: buildAppPopupMenuTheme(palette, textTheme),
    snackBarTheme: buildAppSnackBarTheme(palette, textTheme),
    chipTheme: buildAppChipTheme(palette, textTheme),
    switchTheme: buildAppSwitchTheme(palette),
    checkboxTheme: buildAppCheckboxTheme(palette),
    radioTheme: buildAppRadioTheme(palette),
    segmentedButtonTheme: buildAppSegmentedButtonTheme(palette, textTheme),
    tabBarTheme: buildAppTabBarTheme(palette, textTheme),
    listTileTheme: buildAppListTileTheme(palette, textTheme),
    dividerTheme: buildAppDividerTheme(palette),
    progressIndicatorTheme: buildAppProgressTheme(palette),
    navigationBarTheme: buildAppNavigationBarTheme(palette, textTheme),
    bottomNavigationBarTheme: buildAppBottomNavigationBarTheme(
      palette,
      textTheme,
    ),
    navigationRailTheme: buildAppNavigationRailTheme(palette, textTheme),
    drawerTheme: buildAppDrawerTheme(palette),
    datePickerTheme: buildAppDatePickerTheme(palette),
    timePickerTheme: buildAppTimePickerTheme(palette),
    dropdownMenuTheme: buildAppDropdownMenuTheme(
      palette,
      textTheme,
      inputTheme,
    ),
    menuTheme: buildAppMenuTheme(palette),
    tooltipTheme: buildAppTooltipTheme(palette, textTheme),
    searchBarTheme: buildAppSearchBarTheme(palette, textTheme),
  );
}
