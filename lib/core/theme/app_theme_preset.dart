import 'package:flutter/material.dart';

enum AppThemePreset {
  indigo,
  emerald,
  ocean,
  sunset,
  rose,
  violet,
  amber,
  graphite,
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
      case AppThemePreset.violet:
        return 'Violet';
      case AppThemePreset.amber:
        return 'Amber';
      case AppThemePreset.graphite:
        return 'Graphite';
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
      case AppThemePreset.violet:
        return const Color(0xFF7C3AED);
      case AppThemePreset.amber:
        return const Color(0xFFB45309);
      case AppThemePreset.graphite:
        return const Color(0xFF475569);
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
      case AppThemePreset.violet:
        return const Color(0xFFC026D3);
      case AppThemePreset.amber:
        return const Color(0xFFCA8A04);
      case AppThemePreset.graphite:
        return const Color(0xFF64748B);
    }
  }

  static AppThemePreset fromStorage(String? value) {
    return AppThemePreset.values.firstWhere(
      (preset) => preset.storageValue == value,
      orElse: () => AppThemePreset.indigo,
    );
  }
}
