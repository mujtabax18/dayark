/// Logical settings only. Credentials belong in provider-specific secure storage.
class AiSettings {
  AiSettings({
    this.temperature,
    this.maxOutputTokens,
    this.contextWindowTokens,
    this.customInstructions = '',
    this.sendAdditionalPrompt = true,
    this.responseLanguage,
    this.inputLanguage,
    this.thinking,
    this.performanceProfile = 'custom',
    this.useMemory = true,
    this.idleTimeoutMinutes = 5,
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
  final bool sendAdditionalPrompt;
  final String? responseLanguage;
  final String? inputLanguage;
  final bool? thinking;
  final String performanceProfile;
  final bool useMemory;
  final int idleTimeoutMinutes;
  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'maxOutputTokens': maxOutputTokens,
    'contextWindowTokens': contextWindowTokens,
    'customInstructions': customInstructions,
    'sendAdditionalPrompt': sendAdditionalPrompt,
    'responseLanguage': responseLanguage,
    'inputLanguage': inputLanguage,
    'thinking': thinking,
    'performanceProfile': performanceProfile,
    'useMemory': useMemory,
    'idleTimeoutMinutes': idleTimeoutMinutes,
  };
  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
    temperature: (json['temperature'] as num?)?.toDouble(),
    maxOutputTokens: json['maxOutputTokens'] as int?,
    contextWindowTokens: json['contextWindowTokens'] as int?,
    customInstructions: json['customInstructions'] as String? ?? '',
    sendAdditionalPrompt: json['sendAdditionalPrompt'] as bool? ?? true,
    responseLanguage: json['responseLanguage'] as String?,
    inputLanguage: json['inputLanguage'] as String?,
    thinking: json['thinking'] as bool?,
    performanceProfile: json['performanceProfile'] as String? ?? 'custom',
    useMemory: json['useMemory'] as bool? ?? true,
    idleTimeoutMinutes: (json['idleTimeoutMinutes'] as int? ?? 5).clamp(0, 120),
  );
}
