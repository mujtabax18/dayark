import 'package:flutter/material.dart';

import 'app_theme_extension.dart';

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  AppThemeColors get themeColors => theme.extension<AppThemeColors>()!;
  AppThemeColors get appColors => themeColors;
  bool get isDarkMode => theme.brightness == Brightness.dark;
}
