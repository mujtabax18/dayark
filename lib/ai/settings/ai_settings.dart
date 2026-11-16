/// Logical settings only. Credentials belong in provider-specific secure storage.
class AiSettings {
  AiSettings({
    this.temperature,
    this.maxOutputTokens,
    this.contextWindowTokens,
    this.customInstructions = '',
    this.responseLanguage,
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
}
