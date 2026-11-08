class ProfileState {
  final List<Map<String, dynamic>> profiles;
  final bool isLoading;
  final String? error;

  ProfileState({
    this.profiles = const [],
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    List<Map<String, dynamic>>? profiles,
    bool? isLoading,
    String? error,
  }) {
    return ProfileState(
      profiles: profiles ?? this.profiles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
