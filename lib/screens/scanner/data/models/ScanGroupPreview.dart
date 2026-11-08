class ScanGroupPreview {
  const ScanGroupPreview({
    required this.id,
    required this.title,
    required this.thumbnailPath,
    this.pageCount = 0,
    this.totalBytes = 0,
    this.isFavorite = false,
    this.createdAt = '',
    this.updatedAt = '',
    this.tags = '',
  });

  final int id;
  final String title;
  final String thumbnailPath;
  final int pageCount;
  final int totalBytes;
  final bool isFavorite;
  final String createdAt;
  final String updatedAt;
  final String tags;
}
