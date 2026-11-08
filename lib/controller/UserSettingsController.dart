import 'package:flutter/material.dart';

import '../core/theme/app_theme_preset.dart';
import '../models/HomeLayoutSettings.dart';
import '../models/currency_setting.dart';
import '../services/localDatabaseServices/UserSettingsRepository.dart';
import '../utlis/enums.dart';

class UserSettingsController {
  UserSettingsController(this.repo);

  final UserSettingsRepository repo;

  Future<ThemeMode> getThemeMode() async {
    final value = await repo.getValue(AppSettingKey.theme);

    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      ThemeMode.light => 'light',
    };
    await repo.setValue(AppSettingKey.theme, value);
  }

  Future<AppThemePreset> getThemePreset() async {
    final value = await repo.getValue(AppSettingKey.themePreset);
    return AppThemePresetX.fromStorage(value);
  }

  Future<void> setThemePreset(AppThemePreset preset) async {
    await repo.setValue(AppSettingKey.themePreset, preset.storageValue);
  }

  Future<String> getLanguage() async {
    final value = await repo.getValue(AppSettingKey.language);
    return switch (value) {
      'ur' => 'ur',
      'ar' => 'ar',
      _ => 'en',
    };
  }

  Future<void> setLanguage(String languageCode) async {
    await repo.setValue(AppSettingKey.language, languageCode);
  }

  Future<CurrencySetting> getCurrencySetting() async {
    final values = await Future.wait<String?>([
      repo.getValue(AppSettingKey.currencyCode),
      repo.getValue(AppSettingKey.currencySymbol),
      repo.getValue(AppSettingKey.currencyName),
    ]);

    return CurrencySetting.fromStored(
      code: values[0],
      symbol: values[1],
      name: values[2],
    );
  }

  Future<void> setCurrencySetting(CurrencySetting currency) async {
    await Future.wait([
      repo.setValue(AppSettingKey.currencyCode, currency.code),
      repo.setValue(AppSettingKey.currencySymbol, currency.symbol),
      repo.setValue(AppSettingKey.currencyName, currency.name),
    ]);
    await repo.replaceLegacyDollarCurrency(currency.symbol);
  }

  Future<bool> hasSeenTutorialWelcome() async {
    return await repo.getValue(AppSettingKey.tutorialSeen) == '1';
  }

  Future<void> markTutorialWelcomeSeen() async {
    await repo.setValue(AppSettingKey.tutorialSeen, '1');
  }

  Future<HomePageStyle> getHomePageStyle() async {
    final value = await repo.getValue(AppSettingKey.homePageStyle);
    return HomePageStyleX.fromStorage(value);
  }

  Future<void> setHomePageStyle(HomePageStyle style) async {
    await repo.setValue(AppSettingKey.homePageStyle, style.storageValue);
  }

  Future<HomeSummaryStyle> getHomeSummaryStyle() async {
    final value = await repo.getValue(AppSettingKey.homeSummaryStyle);
    return HomeSummaryStyleX.fromStorage(value);
  }

  Future<void> setHomeSummaryStyle(HomeSummaryStyle style) async {
    await repo.setValue(AppSettingKey.homeSummaryStyle, style.storageValue);
  }

  Future<HomeCreateStyle> getHomeCreateStyle() async {
    final value = await repo.getValue(AppSettingKey.homeCreateStyle);
    return HomeCreateStyleX.fromStorage(value);
  }

  Future<void> setHomeCreateStyle(HomeCreateStyle style) async {
    await repo.setValue(AppSettingKey.homeCreateStyle, style.storageValue);
  }

  Future<List<int>> getHomeSummaryOrder() async {
    final value = await repo.getValue(AppSettingKey.homeSummaryOrder);
    if (value == null || value.trim().isEmpty) {
      return HomeLayoutSettings.defaultSummaryOrder;
    }

    return HomeLayoutSettings.normalizeSummaryOrder(_parseInts(value));
  }

  Future<void> setHomeSummaryOrder(List<int> order) async {
    final normalized = HomeLayoutSettings.normalizeSummaryOrder(order);
    await repo.setValue(
      AppSettingKey.homeSummaryOrder,
      normalized.join(','),
    );
  }

  Future<Set<int>> getHomeVisibleSummaries() async {
    final value = await repo.getValue(AppSettingKey.homeVisibleSummaries);
    if (value == null) return HomeLayoutSettings.defaultVisibleSummaryIds;
    return HomeLayoutSettings.normalizeVisibleSummaryIds(_parseInts(value));
  }

  Future<void> setHomeVisibleSummaries(Set<int> ids) async {
    final normalized = HomeLayoutSettings.normalizeVisibleSummaryIds(ids);
    await repo.setValue(
      AppSettingKey.homeVisibleSummaries,
      _sortedInts(normalized).join(','),
    );
  }

  Future<List<String>> getHomeQuickActionOrder() async {
    final value = await repo.getValue(AppSettingKey.homeQuickActionOrder);
    if (value == null || value.trim().isEmpty) {
      return HomeLayoutSettings.defaultQuickActionOrder;
    }
    return HomeLayoutSettings.normalizeQuickActionOrder(_parseStrings(value));
  }

  Future<void> setHomeQuickActionOrder(List<String> ids) async {
    final normalized = HomeLayoutSettings.normalizeQuickActionOrder(ids);
    await repo.setValue(
      AppSettingKey.homeQuickActionOrder,
      normalized.join(','),
    );
  }

  Future<Set<String>> getHomeVisibleQuickActions() async {
    final value = await repo.getValue(AppSettingKey.homeVisibleQuickActions);
    if (value == null) return HomeLayoutSettings.defaultVisibleQuickActionIds;
    return HomeLayoutSettings.normalizeVisibleQuickActionIds(
      _parseStrings(value),
    );
  }

  Future<void> setHomeVisibleQuickActions(Set<String> ids) async {
    final normalized = HomeLayoutSettings.normalizeVisibleQuickActionIds(ids);
    final sorted = normalized.toList()..sort();
    await repo.setValue(
      AppSettingKey.homeVisibleQuickActions,
      sorted.join(','),
    );
  }

  Future<Set<int>> getHomeVisibleQuickAccess() async {
    final value = await repo.getValue(AppSettingKey.homeVisibleQuickAccess);
    final migrationDone = await repo.getValue(
      AppSettingKey.familyTreeHomeShortcutMigrated,
    );

    if (value == null) {
      // New installs already receive Family Trees through the defaults. Mark
      // the migration complete so hiding it later remains a user preference.
      if (migrationDone != '1') {
        await repo.setValue(
          AppSettingKey.familyTreeHomeShortcutMigrated,
          '1',
        );
      }
      return HomeLayoutSettings.defaultVisibleQuickAccessIds;
    }

    var visibleIds = HomeLayoutSettings.normalizeVisibleQuickAccessIds(
      _parseInts(value),
    );

    // Existing installs may already have a saved quick-access list from
    // before Family Trees existed. Surface the new feature on Home once, then
    // preserve any later hide/show choice made in Home customization.
    if (migrationDone != '1') {
      visibleIds = HomeLayoutSettings.normalizeVisibleQuickAccessIds({
        ...visibleIds,
        14,
      });
      await Future.wait([
        repo.setValue(
          AppSettingKey.homeVisibleQuickAccess,
          _sortedInts(visibleIds).join(','),
        ),
        repo.setValue(
          AppSettingKey.familyTreeHomeShortcutMigrated,
          '1',
        ),
      ]);
    }

    return visibleIds;
  }

  Future<void> setHomeVisibleQuickAccess(Set<int> ids) async {
    final normalized = HomeLayoutSettings.normalizeVisibleQuickAccessIds(ids);
    await repo.setValue(
      AppSettingKey.homeVisibleQuickAccess,
      _sortedInts(normalized).join(','),
    );
  }

  Future<bool> getHomeQuoteVisible() async {
    final value = await repo.getValue(AppSettingKey.homeQuoteVisible);
    return value != '0';
  }

  Future<void> setHomeQuoteVisible(bool visible) async {
    await repo.setValue(AppSettingKey.homeQuoteVisible, visible ? '1' : '0');
  }

  Future<bool> getNavigationBarVisible() async {
    final value = await repo.getValue(AppSettingKey.showNavigationBar);

    // Navigation is intentionally hidden by default. It only becomes visible
    // after the user explicitly enables it in Settings.
    return value == '1';
  }

  Future<void> setNavigationBarVisible(bool visible) async {
    await repo.setValue(AppSettingKey.showNavigationBar, visible ? '1' : '0');
  }

  Iterable<int> _parseInts(String value) {
    return value
        .split(',')
        .map((item) => int.tryParse(item.trim()))
        .whereType<int>();
  }

  Iterable<String> _parseStrings(String value) {
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty);
  }

  List<int> _sortedInts(Iterable<int> values) {
    return values.toList()..sort();
  }
}
