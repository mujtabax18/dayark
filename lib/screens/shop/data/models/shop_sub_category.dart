class ShopSubCategory {
  final int? id;
  final int? categoryId;
  final String title;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShopSubCategory({
    this.id,
    this.categoryId,
    required this.title,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopSubCategory.fromMap(Map<String, dynamic> map) {
    return ShopSubCategory(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int?,
      title: map['title'] as String,
      imagePath: map['image_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'title': title,
        'image_path': imagePath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ShopSubCategory copyWith({
    int? id,
    int? categoryId,
    String? title,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopSubCategory(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
