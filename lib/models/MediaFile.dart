class MediaFile {
  MediaFile({
    this.id,
    required this.filePath,
    String? originalPath,
    this.editedPath,
    required this.mediaType,
    String? title,
    this.mimeType,
    this.extension,
    this.fileSize = 0,
    this.checksum,
    this.version = 1,
    this.isFavorite = false,
    this.isDeleted = false,
    required this.createdAt,
    String? updatedAt,
  })  : originalPath = _nonEmptyOr(originalPath, filePath),
        title = _nonEmptyOr(title, _fallbackName(filePath)),
        updatedAt = _nonEmptyOr(updatedAt, createdAt);

  final int? id;

  /// Current version shown by the app. Kept for compatibility with old code.
  final String filePath;

  /// Immutable copy imported into app-owned storage.
  final String originalPath;

  /// Latest edited version. Null means the original is current.
  final String? editedPath;

  /// image, video, audio, pdf, or file.
  final String mediaType;
  final String title;
  final String? mimeType;
  final String? extension;
  final int fileSize;
  final String? checksum;
  final int version;
  final bool isFavorite;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  String get currentPath {
    final edited = editedPath?.trim();
    if (edited != null && edited.isNotEmpty) return edited;
    return filePath;
  }

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
  bool get isAudio => mediaType == 'audio';
  bool get isPdf => mediaType == 'pdf';
  bool get hasEdits => version > 1 || (editedPath?.isNotEmpty ?? false);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'original_path': originalPath,
      'edited_path': editedPath,
      'media_type': mediaType,
      'title': title,
      'mime_type': mimeType,
      'extension': extension,
      'file_size': fileSize,
      'checksum': checksum,
      'version': version,
      'is_favorite': isFavorite ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory MediaFile.fromMap(Map<String, dynamic> map) {
    final legacyPath = map['file_path']?.toString() ?? '';
    final original = map['original_path']?.toString();
    final edited = map['edited_path']?.toString();

    return MediaFile(
      id: _asInt(map['id']),
      filePath: legacyPath,
      originalPath:
          original == null || original.trim().isEmpty ? legacyPath : original,
      editedPath: edited == null || edited.trim().isEmpty ? null : edited,
      mediaType: map['media_type']?.toString() ?? 'image',
      title: map['title']?.toString().trim().isNotEmpty == true
          ? map['title'].toString()
          : _fallbackName(legacyPath),
      mimeType: map['mime_type']?.toString(),
      extension: map['extension']?.toString(),
      fileSize: _asInt(map['file_size']) ?? 0,
      checksum: map['checksum']?.toString(),
      version: _asInt(map['version']) ?? 1,
      isFavorite: _asBool(map['is_favorite']),
      isDeleted: _asBool(map['is_deleted']),
      createdAt: map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at']?.toString() ??
          map['created_at']?.toString() ??
          DateTime.now().toIso8601String(),
    );
  }

  MediaFile copyWith({
    int? id,
    String? filePath,
    String? originalPath,
    String? editedPath,
    bool clearEditedPath = false,
    String? mediaType,
    String? title,
    String? mimeType,
    String? extension,
    int? fileSize,
    String? checksum,
    int? version,
    bool? isFavorite,
    bool? isDeleted,
    String? createdAt,
    String? updatedAt,
  }) {
    return MediaFile(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      originalPath: originalPath ?? this.originalPath,
      editedPath: clearEditedPath ? null : (editedPath ?? this.editedPath),
      mediaType: mediaType ?? this.mediaType,
      title: title ?? this.title,
      mimeType: mimeType ?? this.mimeType,
      extension: extension ?? this.extension,
      fileSize: fileSize ?? this.fileSize,
      checksum: checksum ?? this.checksum,
      version: version ?? this.version,
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _nonEmptyOr(String? value, String fallback) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? fallback : normalized;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static String _fallbackName(String path) {
    if (path.trim().isEmpty) return 'Untitled media';
    final normalized = path.replaceAll('\\', '/');
    return normalized.split('/').last;
  }
}
