class ShopDetails {
  final int id; // Always 1
  final String name;
  final String? description;
  final String? logoPath;
  final String? imagePath;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopDetails({
    this.id = 1,
    required this.name,
    this.description,
    this.logoPath,
    this.imagePath,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopDetails.fromMap(Map<String, dynamic> map) {
    return ShopDetails(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      logoPath: map['logo_path'] as String?,
      imagePath: map['image_path'] as String?,
      address: map['address'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'logo_path': logoPath,
        'image_path': imagePath,
        'address': address,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  ShopDetails copyWith({
    String? name,
    String? description,
    String? logoPath,
    String? imagePath,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopDetails(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoPath: logoPath ?? this.logoPath,
      imagePath: imagePath ?? this.imagePath,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
