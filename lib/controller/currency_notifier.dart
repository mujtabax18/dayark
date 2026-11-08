import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/currency_setting.dart';
import 'UserSettingsController.dart';

class CurrencyNotifier extends StateNotifier<CurrencySetting> {
  CurrencyNotifier(this.settingsController, CurrencySetting initialCurrency)
      : super(initialCurrency);

  final UserSettingsController settingsController;

  Future<void> setCurrency(CurrencySetting currency) async {
    state = currency;
    await settingsController.setCurrencySetting(currency);
  }
}

final currencyProvider =
    StateNotifierProvider<CurrencyNotifier, CurrencySetting>((ref) {
  throw UnimplementedError(
    'currencyProvider must be overridden in main()',
  );
});
