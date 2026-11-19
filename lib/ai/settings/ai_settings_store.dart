import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_preferences.dart';
import '../model_manager/model_catalogue.dart';
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
    if ((json['catalogueRevision'] as int? ?? 0) < 3) {
      final saved = (json['catalogue'] as List).cast<Map>();
      final current = AiDefaults.builtIn().toJson()['catalogue'] as List;
      final byId = {for (final entry in current) entry['id']: entry};
      const planningSources = {
        '/google/gemma-4-E4B',
        '/google/gemma-4-12B',
        '/google/gemma-4-26B-A4B',
        '/google/gemma-4-31B',
      };
      for (final raw in saved) {
        final entry = catalogueModelFromJson(Map<String, dynamic>.from(raw));
        final planning =
            entry.source.host == 'huggingface.co' &&
            planningSources.contains(entry.source.path) &&
            entry.artifact == null;
        if (!planning && !AiModelCatalogue.isLegacyEntry(entry)) {
          byId[entry.id] = raw; // Preserve custom entries and edits.
        }
      }
      json['catalogue'] = byId.values.toList();
    }
    if ((json['catalogueRevision'] as int? ?? 0) < 4) {
      final releases = {
        for (final m in AiDefaults.builtIn().catalogue.models) m.id: m,
      };
      // Enrich saved CSV entries without reintroducing deleted models or
      // replacing user edits, custom sources, or custom release dates.
      for (final raw in json['catalogue'] as List) {
        final current = releases[raw['id']];
        if (current == null || raw['source'] != current.source.toString()) {
          continue;
        }
        final metadata = Map<String, dynamic>.from(
          raw['metadata'] as Map? ?? {},
        );
        for (final key in ['familyReleaseDate', 'familyReleaseSource']) {
          if (current.metadata[key] != null) {
            metadata.putIfAbsent(key, () => current.metadata[key]);
          }
        }
        raw['metadata'] = metadata;
      }
    }
    if ((json['catalogueRevision'] as int? ?? 0) < 5) {
      final saved = json['catalogue'] as List;
      final ids = {for (final raw in saved) raw['id']};
      // Append newly introduced models while retaining saved edits and deletions
      // of entries that already existed in the previous catalogue.
      for (final model in AiDefaults.builtIn().catalogue.models) {
        if (model.metadata['evidence'] ==
                'publisher_manifest_not_device_tested' &&
            !ids.contains(model.id)) {
          saved.add(catalogueModelToJson(model));
        }
      }
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
