class ScanGroup {
  const ScanGroup({
    this.id,
    required this.title,
    this.source,
    required this.createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.tags = '',
  });

  final int? id;
  final String title;
  final String? source;
  final String createdAt;
  final String? updatedAt;
  final bool isFavorite;
  final String tags;

  ScanGroup copyWith({
    int? id,
    String? title,
    String? source,
    String? createdAt,
    String? updatedAt,
    bool? isFavorite,
    String? tags,
  }) {
    return ScanGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'created_at': createdAt,
      'updated_at': updatedAt ?? createdAt,
      'is_favorite': isFavorite ? 1 : 0,
      'tags': tags,
    };
  }

  factory ScanGroup.fromMap(Map<String, dynamic> map) {
    return ScanGroup(
      id: _asInt(map['id']),
      title: map['title']?.toString() ?? 'Scanned document',
      source: map['source']?.toString(),
      createdAt:
          map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at']?.toString(),
      isFavorite: _asBool(map['is_favorite']),
      tags: map['tags']?.toString() ?? '',
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
    return value?.toString().toLowerCase() == 'true';
  }
}
