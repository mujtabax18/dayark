import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'UserSettingsController.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this.settingsController, Locale initialLocale)
      : super(initialLocale);

  final UserSettingsController settingsController;

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await settingsController.setLanguage(locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  throw UnimplementedError('localeProvider must be overridden in main()');
});
