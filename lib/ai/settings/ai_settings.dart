/// Logical settings only. Credentials belong in provider-specific secure storage.
class AiSettings {
  AiSettings({
    this.temperature,
    this.maxOutputTokens,
    this.contextWindowTokens,
    this.customInstructions = '',
    this.responseLanguage,
    this.inputLanguage,
    this.thinking,
  }) {
    if (temperature != null && (!temperature!.isFinite || temperature! < 0)) {
      throw ArgumentError.value(temperature, 'temperature');
    }
    if (maxOutputTokens != null && maxOutputTokens! <= 0) {
      throw ArgumentError.value(maxOutputTokens, 'maxOutputTokens');
    }
    if (contextWindowTokens != null && contextWindowTokens! <= 0) {
      throw ArgumentError.value(contextWindowTokens, 'contextWindowTokens');
    }
    if (maxOutputTokens != null &&
        contextWindowTokens != null &&
        maxOutputTokens! > contextWindowTokens!) {
      throw ArgumentError('Output limit exceeds context window.');
    }
  }
  final double? temperature;
  final int? maxOutputTokens;
  final int? contextWindowTokens;
  final String customInstructions;
  final String? responseLanguage;
  final String? inputLanguage;
  final bool? thinking;
  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'maxOutputTokens': maxOutputTokens,
    'contextWindowTokens': contextWindowTokens,
    'customInstructions': customInstructions,
    'responseLanguage': responseLanguage,
    'inputLanguage': inputLanguage,
    'thinking': thinking,
  };
  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
    temperature: (json['temperature'] as num?)?.toDouble(),
    maxOutputTokens: json['maxOutputTokens'] as int?,
    contextWindowTokens: json['contextWindowTokens'] as int?,
    customInstructions: json['customInstructions'] as String? ?? '',
    responseLanguage: json['responseLanguage'] as String?,
    inputLanguage: json['inputLanguage'] as String?,
    thinking: json['thinking'] as bool?,
  );
}
