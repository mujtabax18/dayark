class PillListState {
  final bool isLoading;
  final List<Map<String, dynamic>> pills;
  final String? error;

  PillListState({
    this.isLoading = false,
    this.pills = const [],
    this.error,
  });

  PillListState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? pills,
    String? error,
  }) {
    return PillListState(
      isLoading: isLoading ?? this.isLoading,
      pills: pills ?? this.pills,
      error: error,
    );
  }
}
