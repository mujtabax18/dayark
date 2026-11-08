import '../../data/models/scan_model.dart';

class ScannerState {
  final List<ScanEntry> scans;
  final bool isLoading;
  final int? activeGroupId;

  const ScannerState({
    this.scans = const [],
    this.isLoading = false,
    this.activeGroupId,
  });

  ScannerState copyWith({
    List<ScanEntry>? scans,
    bool? isLoading,
    int? activeGroupId,
  }) {
    return ScannerState(
      scans: scans ?? this.scans,
      isLoading: isLoading ?? this.isLoading,
      activeGroupId: activeGroupId ?? this.activeGroupId,
    );
  }
}
