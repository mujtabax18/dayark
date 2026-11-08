class ShopProduct {
  final int? id;
  final String name;
  final double price;
  final String? description;
  final int? categoryId;
  final int? subcategoryId;
  final String? imagePath;
  final double availableQuantity;
  final int? unitId;
  final double? lowAlertLimit;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShopProduct({
    this.id,
    required this.name,
    required this.price,
    this.description,
    this.categoryId,
    this.subcategoryId,
    this.imagePath,
    required this.availableQuantity,
    this.unitId,
    this.lowAlertLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopProduct.fromMap(Map<String, dynamic> map) {
    return ShopProduct(
      id: map['id'] as int?,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      description: map['description'] as String?,
      categoryId: map['category_id'] as int?,
      subcategoryId: map['subcategory_id'] as int?,
      imagePath: map['image_path'] as String?,
      availableQuantity: (map['available_quantity'] as num).toDouble(),
      unitId: map['unit_id'] as int?,
      lowAlertLimit: map['low_alert_limit'] != null
          ? (map['low_alert_limit'] as num).toDouble()
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'description': description,
        'category_id': categoryId,
        'subcategory_id': subcategoryId,
        'image_path': imagePath,
        'available_quantity': availableQuantity,
        'unit_id': unitId,
        'low_alert_limit': lowAlertLimit,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ShopProduct copyWith({
    int? id,
    String? name,
    double? price,
    String? description,
    int? categoryId,
    int? subcategoryId,
    String? imagePath,
    double? availableQuantity,
    int? unitId,
    double? lowAlertLimit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      imagePath: imagePath ?? this.imagePath,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      unitId: unitId ?? this.unitId,
      lowAlertLimit: lowAlertLimit ?? this.lowAlertLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
