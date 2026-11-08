import 'package:flutter/material.dart';

enum AppThemePreset {
  indigo,
  emerald,
  ocean,
  sunset,
  rose,
}

extension AppThemePresetX on AppThemePreset {
  String get storageValue => name;

  String get label {
    switch (this) {
      case AppThemePreset.indigo:
        return 'Indigo';
      case AppThemePreset.emerald:
        return 'Emerald';
      case AppThemePreset.ocean:
        return 'Ocean';
      case AppThemePreset.sunset:
        return 'Sunset';
      case AppThemePreset.rose:
        return 'Rose';
    }
  }

  Color get primary {
    switch (this) {
      case AppThemePreset.indigo:
        return const Color(0xFF4F46E5);
      case AppThemePreset.emerald:
        return const Color(0xFF059669);
      case AppThemePreset.ocean:
        return const Color(0xFF0284C7);
      case AppThemePreset.sunset:
        return const Color(0xFFEA580C);
      case AppThemePreset.rose:
        return const Color(0xFFE11D48);
    }
  }

  Color get secondary {
    switch (this) {
      case AppThemePreset.indigo:
        return const Color(0xFF7C3AED);
      case AppThemePreset.emerald:
        return const Color(0xFF0D9488);
      case AppThemePreset.ocean:
        return const Color(0xFF2563EB);
      case AppThemePreset.sunset:
        return const Color(0xFFD97706);
      case AppThemePreset.rose:
        return const Color(0xFFDB2777);
    }
  }

  static AppThemePreset fromStorage(String? value) {
    return AppThemePreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => AppThemePreset.indigo,
    );
  }
}
