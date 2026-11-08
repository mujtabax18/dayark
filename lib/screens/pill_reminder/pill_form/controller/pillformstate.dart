class PillFormState {
  final bool isSaving;
  final String? error;
  final List<Map<String, dynamic>> pillTypes;
  final List<Map<String, dynamic>> dosageTypes;

  PillFormState({
    this.isSaving = false,
    this.error,
    this.pillTypes = const [],
    this.dosageTypes = const [],
  });

  PillFormState copyWith({
    bool? isSaving,
    String? error,
    List<Map<String, dynamic>>? pillTypes,
    List<Map<String, dynamic>>? dosageTypes,
  }) {
    return PillFormState(
      isSaving: isSaving ?? this.isSaving,
      error: error,
      pillTypes: pillTypes ?? this.pillTypes,
      dosageTypes: dosageTypes ?? this.dosageTypes,
    );
  }
}
