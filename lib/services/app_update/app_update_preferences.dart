import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppUpdatePreferences {
  AppUpdatePreferences._();

  static final AppUpdatePreferences instance = AppUpdatePreferences._();

  static const String _checkOnStartupKey =
      'app_update_check_for_updates_on_startup';

  /// Defaults to true so update checks remain enabled for existing installs
  /// until the user explicitly disables them.
  final ValueNotifier<bool> checkOnStartupNotifier = ValueNotifier<bool>(true);

  bool _loaded = false;

  bool get checkOnStartup => checkOnStartupNotifier.value;

  Future<bool> load() async {
    if (_loaded) return checkOnStartup;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_checkOnStartupKey) ?? true;
    checkOnStartupNotifier.value = enabled;
    _loaded = true;
    return enabled;
  }

  Future<bool> isCheckOnStartupEnabled() async {
    if (!_loaded) {
      await load();
    }
    return checkOnStartup;
  }

  Future<void> setCheckOnStartup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_checkOnStartupKey, enabled);
    _loaded = true;
    checkOnStartupNotifier.value = enabled;
  }
}
