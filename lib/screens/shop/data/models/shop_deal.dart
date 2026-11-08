class ShopDeal {
  final int? id;
  final String name;
  final String? description;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShopDeal({
    this.id,
    required this.name,
    this.description,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopDeal.fromMap(Map<String, dynamic> map) {
    return ShopDeal(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      price: (map['price'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ShopDeal copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopDeal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
