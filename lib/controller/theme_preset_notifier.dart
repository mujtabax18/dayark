import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../core/theme/app_theme_preset.dart';
import 'UserSettingsController.dart';

class ThemePresetNotifier extends StateNotifier<AppThemePreset> {
  ThemePresetNotifier(this.settingsController, AppThemePreset initialPreset)
      : super(initialPreset);

  final UserSettingsController settingsController;

  Future<void> setPreset(AppThemePreset preset) async {
    state = preset;
    await settingsController.setThemePreset(preset);
  }
}

final themePresetProvider =
    StateNotifierProvider<ThemePresetNotifier, AppThemePreset>((ref) {
  throw UnimplementedError(
    'themePresetProvider must be overridden in main()',
  );
});
