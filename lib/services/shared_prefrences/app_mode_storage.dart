import 'package:shared_preferences/shared_preferences.dart';

import '../../utlis/enums.dart';

class AppModeStorage {
  static const _key = 'app_mode';

  static Future<void> saveMode(AppMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  static Future<AppMode?> getMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == null) return null;
    return AppMode.values.firstWhere((e) => e.name == value);
  }

  static Future<bool> isModeSelected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}
