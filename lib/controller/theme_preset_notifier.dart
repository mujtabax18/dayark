import 'package:flutter_riverpod/legacy.dart';

import '../core/theme/app_theme_preset.dart';
import 'UserSettingsController.dart';

class ThemePresetNotifier extends StateNotifier<AppThemePreset> {
  ThemePresetNotifier(this.settingsController, AppThemePreset initialPreset)
    : super(initialPreset);

  final UserSettingsController settingsController;

  Future<void> setPreset(AppThemePreset preset) async {
    if (state == preset) return;
    await settingsController.setThemePreset(preset);
    if (mounted) state = preset;
  }
}

final themePresetProvider =
    StateNotifierProvider<ThemePresetNotifier, AppThemePreset>((ref) {
      throw UnimplementedError(
        'themePresetProvider must be overridden in main()',
      );
    });
