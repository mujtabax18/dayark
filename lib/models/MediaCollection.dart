class MediaCollection {
  const MediaCollection({
    this.id,
    required this.name,
    this.itemCount = 0,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String name;
  final int itemCount;
  final int sortOrder;
  final String createdAt;
  final String updatedAt;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'sort_order': sortOrder,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory MediaCollection.fromMap(Map<String, dynamic> map) {
    return MediaCollection(
      id: _asInt(map['id']),
      name: map['name']?.toString() ?? 'Untitled collection',
      itemCount: _asInt(map['item_count']) ?? 0,
      sortOrder: _asInt(map['sort_order']) ?? 0,
      createdAt:
          map['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: map['updated_at']?.toString() ??
          map['created_at']?.toString() ??
          DateTime.now().toIso8601String(),
    );
  }

  MediaCollection copyWith({
    int? id,
    String? name,
    int? itemCount,
    int? sortOrder,
    String? createdAt,
    String? updatedAt,
  }) {
    return MediaCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      itemCount: itemCount ?? this.itemCount,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
