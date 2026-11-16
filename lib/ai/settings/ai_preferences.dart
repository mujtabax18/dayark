import '../core/ai_capabilities.dart';
import '../core/ai_provider.dart';
import '../models/ai_models.dart';
import '../providers/http/openai_provider.dart';
import '../providers/http/gemini_provider.dart';
import '../providers/http/anthropic_provider.dart';
import '../providers/http/ollama_provider.dart';
import '../providers/http/compatible_provider.dart';
import 'ai_settings.dart';

enum AiProviderKind { offline, openai, gemini, anthropic, ollama, compatible }

/// Contains no secrets. The profile ID is the secure credential reference.
class AiProviderProfile {
  AiProviderProfile({
    required this.id,
    required this.name,
    required this.kind,
    required this.modelId,
    this.baseUrl,
  }) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id) ||
        name.trim().isEmpty ||
        modelId.trim().isEmpty) {
      throw ArgumentError('Profile name and model ID are required.');
    }
    if (baseUrl != null) {
      final uri = Uri.parse(baseUrl!);
      final local = ['localhost', '127.0.0.1', '::1'].contains(uri.host);
      if (!uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          !(uri.scheme == 'https' || (uri.scheme == 'http' && local))) {
        throw ArgumentError(
          'Use HTTPS, or HTTP on localhost, without credentials or query parameters.',
        );
      }
    }
    if (kind == AiProviderKind.compatible && baseUrl == null) {
      throw ArgumentError('A compatible API requires a base URL.');
    }
  }
  final String id, name, modelId;
  final AiProviderKind kind;
  final String? baseUrl;
  AiModelSelection get selection =>
      AiModelSelection(providerId: id, modelId: modelId);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'modelId': modelId,
    if (baseUrl != null) 'baseUrl': baseUrl,
  };
  factory AiProviderProfile.fromJson(Map<String, dynamic> json) =>
      AiProviderProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        kind: AiProviderKind.values.byName(json['kind'] as String),
        modelId: json['modelId'] as String,
        baseUrl: json['baseUrl'] as String?,
      );

  /// Offline profiles use the existing model manager's provider, never a second engine.
  AiProvider createProvider({
    required Future<String?> Function() credentials,
    AiProvider? offline,
  }) {
    final url = baseUrl == null ? null : Uri.parse(baseUrl!);
    return switch (kind) {
      AiProviderKind.offline =>
        offline != null && !offline.isRemote
            ? offline
            : throw ArgumentError(
                'Supply the existing local model manager provider.',
              ),
      AiProviderKind.openai => OpenAiProvider(
        id: id,
        baseUrl: url,
        credentials: credentials,
      ),
      AiProviderKind.gemini => GeminiProvider(
        id: id,
        baseUrl: url,
        credentials: credentials,
      ),
      AiProviderKind.anthropic => AnthropicProvider(
        id: id,
        baseUrl: url,
        credentials: credentials,
      ),
      AiProviderKind.ollama => OllamaProvider(
        id: id,
        baseUrl: url,
        credentials: credentials,
      ),
      AiProviderKind.compatible => CompatibleApiProvider(
        id: id,
        baseUrl: url!,
        credentials: credentials,
      ),
    };
  }
}

class AiPreferences {
  AiPreferences({
    Iterable<AiProviderProfile> profiles = const [],
    this.selectedProfileId,
    AiSettings? settings,
    this.allowOnlineProcessing = false,
    this.allowPrivateContextOnline = false,
  }) : profiles = List.unmodifiable(profiles),
       settings = settings ?? AiSettings() {
    if (this.profiles.map((p) => p.id).toSet().length != this.profiles.length ||
        (selectedProfileId != null &&
            !this.profiles.any((p) => p.id == selectedProfileId))) {
      throw ArgumentError('Invalid profile selection.');
    }
  }
  final List<AiProviderProfile> profiles;
  final String? selectedProfileId;
  final AiSettings settings;
  final bool allowOnlineProcessing, allowPrivateContextOnline;
  AiProviderProfile? get selectedProfile =>
      profiles.where((p) => p.id == selectedProfileId).firstOrNull;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'profiles': profiles.map((p) => p.toJson()).toList(),
    'selectedProfileId': selectedProfileId,
    'settings': settings.toJson(),
    'allowOnlineProcessing': allowOnlineProcessing,
    'allowPrivateContextOnline': allowPrivateContextOnline,
  };
  factory AiPreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported AI preferences version.');
    }
    return AiPreferences(
      profiles: (json['profiles'] as List).map(
        (p) => AiProviderProfile.fromJson(Map<String, dynamic>.from(p as Map)),
      ),
      selectedProfileId: json['selectedProfileId'] as String?,
      settings: AiSettings.fromJson(
        Map<String, dynamic>.from(json['settings'] as Map),
      ),
      allowOnlineProcessing: json['allowOnlineProcessing'] == true,
      allowPrivateContextOnline: json['allowPrivateContextOnline'] == true,
    );
  }
}

/// Retain stored values across switches, but send only parameters supported by the model.
AiSettings settingsForCapabilities(
  AiSettings settings,
  AiCapabilities capabilities,
) => AiSettings(
  temperature: capabilities.temperature
      ? (capabilities.maxTemperature != null && settings.temperature != null
            ? settings.temperature!
                  .clamp(0, capabilities.maxTemperature!)
                  .toDouble()
            : settings.temperature)
      : null,
  maxOutputTokens: capabilities.outputTokenLimit
      ? settings.maxOutputTokens
      : null,
  contextWindowTokens: capabilities.contextWindow
      ? settings.contextWindowTokens
      : null,
  customInstructions: settings.customInstructions,
  responseLanguage: settings.responseLanguage,
  inputLanguage: settings.inputLanguage,
);
