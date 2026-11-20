import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Device-only layout, bounded drafts and user-authored templates. No AI calls.
class AiWorkspaceStore {
  AiWorkspaceStore(this.preferences);
  final SharedPreferences preferences;
  static const _prefix = 'dayark.ai.workspace.';
  bool get sidebarCollapsed =>
      preferences.getBool('${_prefix}collapsed') ?? false;
  double get sidebarWidth =>
      (preferences.getDouble('${_prefix}width') ?? 240).clamp(200, 360);
  bool get enterToSend => preferences.getBool('${_prefix}enterToSend') ?? false;
  Future<void> setEnterToSend(bool value) async {
    if (!await preferences.setBool('${_prefix}enterToSend', value)) {
      throw StateError('Unable to save keyboard preferences.');
    }
  }

  bool get inspector => preferences.getBool('${_prefix}inspector') ?? true;
  Future<void> layout({bool? collapsed, double? width, bool? inspector}) async {
    if (collapsed != null) {
      await preferences.setBool('${_prefix}collapsed', collapsed);
    }
    if (width != null) {
      await preferences.setDouble('${_prefix}width', width.clamp(200, 360));
    }
    if (inspector != null) {
      await preferences.setBool('${_prefix}inspector', inspector);
    }
  }

  Map<String, dynamic> _read(String key) {
    try {
      return jsonDecode(preferences.getString('$_prefix$key') ?? '{}')
          as Map<String, dynamic>;
    } on FormatException {
      return {};
    }
  }

  String draft(String? id) => _read('drafts')[id ?? 'new'] as String? ?? '';
  Future<void> saveDraft(String? id, String text) async {
    final drafts = _read('drafts');
    final key = id ?? 'new';
    drafts.remove(key);
    if (text.isNotEmpty) {
      drafts[key] = text.substring(0, text.length.clamp(0, 32000));
    }
    while (drafts.length > 20) {
      drafts.remove(drafts.keys.first);
    }
    await preferences.setString('${_prefix}drafts', jsonEncode(drafts));
  }

  List<Map<String, dynamic>> get templates =>
      (_read('prompts')['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<void> saveTemplates(List<Map<String, dynamic>> items) async {
    if (items.length > 100) throw StateError('Keep up to 100 templates.');
    await preferences.setString(
      '${_prefix}prompts',
      jsonEncode({'items': items}),
    );
  }
}
