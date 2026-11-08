class ShopUnit {
  final int? id;
  final String name;

  ShopUnit({
    this.id,
    required this.name,
  });

  factory ShopUnit.fromMap(Map<String, dynamic> map) {
    return ShopUnit(
      id: map['id'] as int?,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      };

  ShopUnit copyWith({
    int? id,
    String? name,
  }) {
    return ShopUnit(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
