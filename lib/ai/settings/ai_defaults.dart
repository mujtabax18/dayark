import '../model_manager/model_catalogue.dart';
import 'ai_preferences.dart';

/// Versioned user-editable defaults. Never includes credentials or enables network access.
class AiProviderDefaults {
  AiProviderDefaults({
    required this.kind,
    required Iterable<String> models,
    this.baseUrl,
    this.temperature = .7,
    this.outputTokens = 2048,
    this.contextTokens = 4096,
  }) : models = List.unmodifiable(models) {
    if (this.models.isEmpty ||
        models.any((m) => m.trim().isEmpty) ||
        models.toSet().length != models.length ||
        !temperature.isFinite ||
        temperature < 0 ||
        temperature > 2 ||
        outputTokens < 1 ||
        contextTokens < outputTokens) {
      throw ArgumentError(
        'Provide unique model IDs and valid generation defaults.',
      );
    }
    if (kind != AiProviderKind.offline) {
      AiProviderProfile(
        id: 'defaults',
        name: 'Defaults',
        kind: kind,
        modelId: models.first,
        baseUrl: baseUrl,
      );
    }
  }
  final AiProviderKind kind;
  final List<String> models;
  final String? baseUrl;
  final double temperature;
  final int outputTokens, contextTokens;
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'models': models,
    'baseUrl': baseUrl,
    'temperature': temperature,
    'outputTokens': outputTokens,
    'contextTokens': contextTokens,
  };
  factory AiProviderDefaults.fromJson(Map<String, dynamic> j) =>
      AiProviderDefaults(
        kind: AiProviderKind.values.byName(j['kind'] as String),
        models: List<String>.unmodifiable((j['models'] as List).cast<String>()),
        baseUrl: j['baseUrl'] as String?,
        temperature: (j['temperature'] as num).toDouble(),
        outputTokens: j['outputTokens'] as int,
        contextTokens: j['contextTokens'] as int,
      );
}

class AiDefaults {
  AiDefaults({
    required Iterable<AiProviderDefaults> providers,
    required this.catalogue,
  }) : providers = List.unmodifiable(providers) {
    if (this.providers.map((p) => p.kind).toSet().length !=
            AiProviderKind.values.length ||
        this.providers.length != AiProviderKind.values.length) {
      throw ArgumentError('One default per provider is required.');
    }
  }
  final List<AiProviderDefaults> providers;
  final AiModelCatalogue catalogue;
  AiProviderDefaults forKind(AiProviderKind kind) =>
      providers.firstWhere((p) => p.kind == kind);
  static const reviewed = '2026-11-16';
  factory AiDefaults.builtIn() => AiDefaults(
    providers: [
      AiProviderDefaults(kind: AiProviderKind.offline, models: ['gemma4-e4b']),
      AiProviderDefaults(
        kind: AiProviderKind.openai,
        baseUrl: 'https://api.openai.com/v1/',
        models: ['gpt-6.1-sol', 'gpt-6-sol', 'gpt-5.6-sol', 'gpt-5.4-mini'],
      ),
      AiProviderDefaults(
        kind: AiProviderKind.gemini,
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/',
        models: [
          'gemini-4-hydrogen',
          'gemini-4-argon',
          'gemini-4-carbon',
          'gemini-3.8-flash',
        ],
      ),
      AiProviderDefaults(
        kind: AiProviderKind.anthropic,
        baseUrl: 'https://api.anthropic.com/v1/',
        models: [
          'claude-sonnet-5-5',
          'claude-haiku-5-5',
          'claude-opus-5-5',
          'claude-fable-5-2',
        ],
      ),
      AiProviderDefaults(
        kind: AiProviderKind.ollama,
        baseUrl: 'http://localhost:11434/api/',
        models: ['gemma4:e4b', 'gemma4:12b', 'gemma4:26b', 'gemma4:31b'],
      ),
      // Compatible servers have no universal model name; discover or edit this example.
      AiProviderDefaults(
        kind: AiProviderKind.compatible,
        baseUrl: 'http://localhost:1234/v1/',
        models: ['local-model'],
      ),
    ],
    catalogue: AiModelCatalogue.candidates(),
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'providers': providers.map((p) => p.toJson()).toList(),
    'catalogue': catalogue.models.map(catalogueModelToJson).toList(),
  };
  factory AiDefaults.fromJson(Map<String, dynamic> j) {
    if (j['version'] != 1) {
      throw const FormatException('Unsupported defaults version.');
    }
    return AiDefaults(
      providers: (j['providers'] as List).map(
        (p) => AiProviderDefaults.fromJson(Map<String, dynamic>.from(p as Map)),
      ),
      catalogue: AiModelCatalogue(
        (j['catalogue'] as List).map(
          (p) => catalogueModelFromJson(Map<String, dynamic>.from(p as Map)),
        ),
      ),
    );
  }
}

Map<String, dynamic> catalogueModelToJson(AiCatalogueModel m) => {
  'id': m.id,
  'name': m.name,
  'license': m.license,
  'source': m.source.toString(),
  'estimatedRamBytes': m.estimatedRamBytes,
  'estimatedDiskBytes': m.estimatedDiskBytes,
  'contextSize': m.contextSize,
  'quantization': m.quantization,
  'languages': m.languages,
  if (m.artifact case final a?)
    'artifact': {
      'url': a.url.toString(),
      'sha256': a.sha256,
      'bytes': a.bytes,
      'revision': a.revision,
      'redirectHosts': a.redirectHosts.toList(),
    },
};
AiCatalogueModel catalogueModelFromJson(Map<String, dynamic> j) {
  final a = j['artifact'] as Map?;
  final source = Uri.parse(j['source'] as String);
  if (source.scheme != 'https' ||
      source.host.isEmpty ||
      source.userInfo.isNotEmpty ||
      source.hasQuery ||
      source.hasFragment) {
    throw ArgumentError('Catalogue source must be a public HTTPS URL.');
  }
  return AiCatalogueModel(
    id: j['id'] as String,
    name: j['name'] as String,
    license: j['license'] as String,
    source: source,
    estimatedRamBytes: j['estimatedRamBytes'] as int,
    estimatedDiskBytes: j['estimatedDiskBytes'] as int,
    contextSize: j['contextSize'] as int,
    quantization: j['quantization'] as String,
    languages: (j['languages'] as List).cast<String>(),
    artifact: a == null
        ? null
        : AiModelArtifact(
            url: Uri.parse(a['url'] as String),
            sha256: a['sha256'] as String,
            bytes: a['bytes'] as int,
            revision: a['revision'] as String,
            redirectHosts: (a['redirectHosts'] as List).cast<String>(),
          ),
  );
}
