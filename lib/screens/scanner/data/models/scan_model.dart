class ScanEntry {
  const ScanEntry({
    this.id,
    required this.originalPath,
    required this.editedPath,
    required this.createdAt,
    this.groupId,
    this.sortId,
    this.title = '',
    this.notes = '',
    this.ocrText = '',
    this.fileSize = 0,
    this.checksum,
    this.version = 1,
    this.isFavorite = false,
    this.updatedAt,
  });

  final int? id;
  final String originalPath;
  final String editedPath;
  final String createdAt;
  final int? groupId;
  final int? sortId;
  final String title;
  final String notes;
  final String ocrText;
  final int fileSize;
  final String? checksum;
  final int version;
  final bool isFavorite;
  final String? updatedAt;

  String get currentPath =>
      editedPath.trim().isNotEmpty ? editedPath : originalPath;

  ScanEntry copyWith({
    int? id,
    String? originalPath,
    String? editedPath,
    String? createdAt,
    int? groupId,
    int? sortId,
    String? title,
    String? notes,
    String? ocrText,
    int? fileSize,
    String? checksum,
    int? version,
    bool? isFavorite,
    String? updatedAt,
  }) {
    return ScanEntry(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      editedPath: editedPath ?? this.editedPath,
      createdAt: createdAt ?? this.createdAt,
      groupId: groupId ?? this.groupId,
      sortId: sortId ?? this.sortId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      ocrText: ocrText ?? this.ocrText,
      fileSize: fileSize ?? this.fileSize,
      checksum: checksum ?? this.checksum,
      version: version ?? this.version,
      isFavorite: isFavorite ?? this.isFavorite,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'original_path': originalPath,
      'edited_path': editedPath,
      'created_at': createdAt,
      'group_id': groupId,
      'sort_id': sortId ?? 0,
      'title': title,
      'notes': notes,
      'ocr_text': ocrText,
      'file_size': fileSize,
      'checksum': checksum,
      'version': version,
      'is_favorite': isFavorite ? 1 : 0,
      'updated_at': updatedAt ?? createdAt,
    };
  }

  factory ScanEntry.fromMap(Map<String, dynamic> map) {
    final originalPath = map['original_path']?.toString() ?? '';
    final editedPath = map['edited_path']?.toString();
    return ScanEntry(
      id: _asInt(map['id']),
      originalPath: originalPath,
      editedPath: editedPath == null || editedPath.trim().isEmpty
          ? originalPath
          : editedPath,
      createdAt:
          map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      groupId: _asInt(map['group_id']),
      sortId: _asInt(map['sort_id']) ?? 0,
      title: map['title']?.toString() ?? '',
      notes: map['notes']?.toString() ?? '',
      ocrText: map['ocr_text']?.toString() ?? '',
      fileSize: _asInt(map['file_size']) ?? 0,
      checksum: map['checksum']?.toString(),
      version: _asInt(map['version']) ?? 1,
      isFavorite: _asBool(map['is_favorite']),
      updatedAt: map['updated_at']?.toString(),
    );
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
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}
