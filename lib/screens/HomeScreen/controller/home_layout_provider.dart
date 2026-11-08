import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../controller/UserSettingsController.dart';
import '../../../controller/theme_notifier.dart';
import '../../../models/HomeLayoutSettings.dart';

class HomeLayoutNotifier extends StateNotifier<HomeLayoutSettings> {
  HomeLayoutNotifier(this._settingsController)
      : super(const HomeLayoutSettings()) {
    load();
  }

  final UserSettingsController _settingsController;

  Future<void> load() async {
    try {
      final values = await Future.wait<dynamic>([
        _settingsController.getHomePageStyle(),
        _settingsController.getHomeSummaryStyle(),
        _settingsController.getHomeCreateStyle(),
        _settingsController.getHomeSummaryOrder(),
        _settingsController.getHomeVisibleSummaries(),
        _settingsController.getHomeQuickActionOrder(),
        _settingsController.getHomeVisibleQuickActions(),
        _settingsController.getHomeVisibleQuickAccess(),
        _settingsController.getHomeQuoteVisible(),
        _settingsController.getNavigationBarVisible(),
      ]);

      state = HomeLayoutSettings(
        style: values[0] as HomePageStyle,
        summaryStyle: values[1] as HomeSummaryStyle,
        createStyle: values[2] as HomeCreateStyle,
        summaryOrder: HomeLayoutSettings.normalizeSummaryOrder(
          values[3] as List<int>,
        ),
        visibleSummaryIds: HomeLayoutSettings.normalizeVisibleSummaryIds(
          values[4] as Set<int>,
        ),
        quickActionOrder: HomeLayoutSettings.normalizeQuickActionOrder(
          values[5] as List<String>,
        ),
        visibleQuickActionIds:
            HomeLayoutSettings.normalizeVisibleQuickActionIds(
          values[6] as Set<String>,
        ),
        visibleQuickAccessIds:
            HomeLayoutSettings.normalizeVisibleQuickAccessIds(
          values[7] as Set<int>,
        ),
        showQuote: values[8] as bool,
        showNavigationBar: values[9] as bool,
      );
    } catch (_) {
      // Keep the current in-memory layout when stored settings are unavailable.
    }
  }

  Future<void> setStyle(HomePageStyle style) async {
    if (state.style == style) return;
    state = state.copyWith(style: style);
    await _settingsController.setHomePageStyle(style);
  }

  Future<void> setSummaryStyle(HomeSummaryStyle style) async {
    if (state.summaryStyle == style) return;
    state = state.copyWith(summaryStyle: style);
    await _settingsController.setHomeSummaryStyle(style);
  }

  Future<void> setCreateStyle(HomeCreateStyle style) async {
    if (state.createStyle == style) return;
    state = state.copyWith(createStyle: style);
    await _settingsController.setHomeCreateStyle(style);
  }

  Future<void> updateSummaryOrder(List<int> order) async {
    final normalized = HomeLayoutSettings.normalizeSummaryOrder(order);
    state = state.copyWith(summaryOrder: normalized);
    await _settingsController.setHomeSummaryOrder(normalized);
  }

  Future<void> setSummaryVisible(int id, bool visible) async {
    final updated = {...state.visibleSummaryIds};
    visible ? updated.add(id) : updated.remove(id);
    final normalized = HomeLayoutSettings.normalizeVisibleSummaryIds(updated);
    state = state.copyWith(visibleSummaryIds: normalized);
    await _settingsController.setHomeVisibleSummaries(normalized);
  }

  Future<void> updateQuickActionOrder(List<String> order) async {
    final normalized = HomeLayoutSettings.normalizeQuickActionOrder(order);
    state = state.copyWith(quickActionOrder: normalized);
    await _settingsController.setHomeQuickActionOrder(normalized);
  }

  Future<void> setQuickActionVisible(String id, bool visible) async {
    final updated = {...state.visibleQuickActionIds};
    visible ? updated.add(id) : updated.remove(id);
    final normalized =
        HomeLayoutSettings.normalizeVisibleQuickActionIds(updated);
    state = state.copyWith(visibleQuickActionIds: normalized);
    await _settingsController.setHomeVisibleQuickActions(normalized);
  }

  Future<void> setQuickAccessVisible(int id, bool visible) async {
    final updated = {...state.visibleQuickAccessIds};
    visible ? updated.add(id) : updated.remove(id);
    final normalized = HomeLayoutSettings.normalizeVisibleQuickAccessIds(
      updated,
    );
    state = state.copyWith(visibleQuickAccessIds: normalized);
    await _settingsController.setHomeVisibleQuickAccess(normalized);
  }

  Future<void> setQuoteVisible(bool visible) async {
    if (state.showQuote == visible) return;
    state = state.copyWith(showQuote: visible);
    await _settingsController.setHomeQuoteVisible(visible);
  }

  Future<void> setNavigationBarVisible(bool visible) async {
    if (state.showNavigationBar == visible) return;
    state = state.copyWith(showNavigationBar: visible);
    await _settingsController.setNavigationBarVisible(visible);
  }
}

final homeLayoutProvider =
    StateNotifierProvider<HomeLayoutNotifier, HomeLayoutSettings>((ref) {
  return HomeLayoutNotifier(ref.read(userSettingsControllerProvider));
});
