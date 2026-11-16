import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_preferences.dart';

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

  Future<String?> credential(String profileId) =>
      credentials.read(key: _credentialKey(profileId));
  Future<void> setCredential(String profileId, String value) =>
      value.trim().isEmpty
      ? credentials.delete(key: _credentialKey(profileId))
      : credentials.write(key: _credentialKey(profileId), value: value.trim());
  Future<void> deleteCredential(String profileId) =>
      credentials.delete(key: _credentialKey(profileId));
}
