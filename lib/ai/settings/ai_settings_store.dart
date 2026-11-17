import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_preferences.dart';
import 'ai_defaults.dart';

/// Normal preferences never contain credentials. Storage failures propagate to the UI.
class AiSettingsStore {
  AiSettingsStore({
    required this.preferences,
    this.credentials = const FlutterSecureStorage(),
  });
  final SharedPreferences preferences;
  final FlutterSecureStorage credentials;
  static const key = 'dayark.ai.preferences.v1';
  String _credentialKey(String id) => 'dayark.ai.credential.$id';
  AiPreferences load() {
    final value = preferences.getString(key);
    return value == null
        ? AiPreferences()
        : AiPreferences.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> save(AiPreferences value) async {
    if (!await preferences.setString(key, jsonEncode(value.toJson()))) {
      throw StateError('AI settings could not be saved.');
    }
  }

  static const defaultsKey = 'dayark.ai.defaults.v1';
  AiDefaults loadDefaults() {
    final value = preferences.getString(defaultsKey);
    if (value == null) return AiDefaults.builtIn();
    final json = jsonDecode(value) as Map<String, dynamic>;
    if (json['catalogueRevision'] == null) {
      // Upgrade the original planning-only catalogue while retaining custom
      // entries and provider settings. Future user edits stay authoritative.
      final builtIn = AiDefaults.builtIn().toJson()['catalogue'] as List;
      final saved = json['catalogue'] as List;
      final byId = {for (final entry in builtIn) entry['id']: entry};
      const legacySources = {
        'gemma4-e4b': '/google/gemma-4-E4B',
        'gemma4-12b': '/google/gemma-4-12B',
        'gemma4-26b': '/google/gemma-4-26B-A4B',
        'gemma4-31b': '/google/gemma-4-31B',
      };
      for (final entry in saved) {
        final source = Uri.tryParse(entry['source'] as String? ?? '');
        final replacement = byId[entry['id']];
        final original =
            source?.host == 'huggingface.co' &&
            legacySources[entry['id']] == source?.path;
        byId[entry['id']] =
            original && entry['artifact'] == null && replacement != null
            ? {
                ...entry,
                'artifact': replacement['artifact'],
                'quantization': replacement['quantization'],
              }
            : entry;
      }
      json['catalogue'] = byId.values.toList();
    }
    return AiDefaults.fromJson(json);
  }

  Future<void> saveDefaults(AiDefaults defaults) async {
    if (!await preferences.setString(
      defaultsKey,
      jsonEncode(defaults.toJson()),
    )) {
      throw StateError('AI defaults could not be saved.');
    }
  }

  Future<String?> credential(String profileId) =>
      credentials.read(key: _credentialKey(profileId));
  Future<void> setCredential(String profileId, String value) =>
      value.trim().isEmpty
      ? credentials.delete(key: _credentialKey(profileId))
      : credentials.write(key: _credentialKey(profileId), value: value.trim());
  Future<void> deleteCredential(String profileId) =>
      credentials.delete(key: _credentialKey(profileId));
}
