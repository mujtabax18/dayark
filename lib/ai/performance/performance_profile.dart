import '../settings/ai_settings.dart';

enum AiPerformanceProfile {
  fast('Fast'),
  balanced('Balanced'),
  quality('Quality'),
  custom('Custom');

  const AiPerformanceProfile(this.label);
  final String label;

  /// Context is a request ceiling. Native allocations remain hardware/model bound.
  AiSettings apply(AiSettings current, {required bool mobile}) {
    if (this == custom) return current;
    final context = switch (this) {
      fast => mobile ? 2048 : 4096,
      balanced => mobile ? 4096 : 8192,
      _ => mobile ? 8192 : 16384,
    };
    return AiSettings.fromJson({
      ...current.toJson(),
      'contextWindowTokens': context,
      'maxOutputTokens': switch (this) {
        fast => mobile ? 256 : 512,
        balanced => 1024,
        _ => 2048,
      },
      'thinking': this == quality
          ? true
          : this == fast
          ? false
          : null,
      'performanceProfile': name,
    });
  }
}
