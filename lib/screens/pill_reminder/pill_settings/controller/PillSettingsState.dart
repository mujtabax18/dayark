class PillSettingsState {
  final List<Map<String, dynamic>> pillTypes;
  final List<Map<String, dynamic>> dosageTypes;
  final bool isLoading;
  final String? error;

  PillSettingsState({
    this.pillTypes = const [],
    this.dosageTypes = const [],
    this.isLoading = false,
    this.error,
  });

  PillSettingsState copyWith({
    List<Map<String, dynamic>>? pillTypes,
    List<Map<String, dynamic>>? dosageTypes,
    bool? isLoading,
    String? error,
  }) {
    return PillSettingsState(
      pillTypes: pillTypes ?? this.pillTypes,
      dosageTypes: dosageTypes ?? this.dosageTypes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
