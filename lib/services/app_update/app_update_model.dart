class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.assetName,
    required this.assetUrl,
    required this.releaseUrl,
    required this.assetSize,
    this.assetDigest,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  /// The package selected for the *current* operating system.
  final String assetName;
  final String assetUrl;
  final String releaseUrl;
  final int assetSize;
  final String? assetDigest;

  String get formattedSize {
    if (assetSize <= 0) return 'Unknown size';
    final mb = assetSize / (1024 * 1024);
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
}
