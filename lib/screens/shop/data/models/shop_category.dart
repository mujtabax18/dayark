class ShopCategory {
  final int? id;
  final String title;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShopCategory({
    this.id,
    required this.title,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopCategory.fromMap(Map<String, dynamic> map) {
    return ShopCategory(
      id: map['id'],
      title: map['title'],
      imagePath: map['image_path'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'image_path': imagePath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
