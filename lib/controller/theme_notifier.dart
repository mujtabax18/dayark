import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/database_service.dart';
import '../services/localDatabaseServices/UserSettingsRepository.dart';
import 'UserSettingsController.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final UserSettingsController settingsController;

  ThemeNotifier(
    this.settingsController,
    ThemeMode initialMode,
  ) : super(initialMode);

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await settingsController.setThemeMode(mode);
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newMode);
  }
}

/// Repository
final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(ref.read(databaseServiceProvider));
});

/// Controller
final userSettingsControllerProvider = Provider<UserSettingsController>((ref) {
  return UserSettingsController(
    ref.read(userSettingsRepositoryProvider),
  );
});

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  throw UnimplementedError(
    'themeProvider must be overridden in main()',
  );
});
