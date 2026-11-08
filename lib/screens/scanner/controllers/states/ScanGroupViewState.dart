import '../../data/models/scan_model.dart';

class ScanGroupViewState {
  final bool isLoading;
  final String title;
  final List<ScanEntry> scans;

  /// Selection
  final bool selectionMode;
  final Set<int> selectedIds;

  const ScanGroupViewState({
    this.isLoading = false,
    this.title = '',
    this.scans = const [],
    this.selectionMode = false,
    this.selectedIds = const {},
  });

  ScanGroupViewState copyWith({
    bool? isLoading,
    String? title,
    List<ScanEntry>? scans,
    bool? selectionMode,
    Set<int>? selectedIds,
  }) {
    return ScanGroupViewState(
      isLoading: isLoading ?? this.isLoading,
      title: title ?? this.title,
      scans: scans ?? this.scans,
      selectionMode: selectionMode ?? this.selectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}
