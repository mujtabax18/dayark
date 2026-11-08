class ShopDealProduct {
  final int? id;
  final int dealId;
  final int productId;
  final double quantity;

  ShopDealProduct({
    this.id,
    required this.dealId,
    required this.productId,
    required this.quantity,
  });

  factory ShopDealProduct.fromMap(Map<String, dynamic> map) {
    return ShopDealProduct(
      id: map['id'] as int?,
      dealId: map['deal_id'] as int,
      productId: map['product_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'deal_id': dealId,
        'product_id': productId,
        'quantity': quantity,
      };

  ShopDealProduct copyWith({
    int? id,
    int? dealId,
    int? productId,
    double? quantity,
  }) {
    return ShopDealProduct(
      id: id ?? this.id,
      dealId: dealId ?? this.dealId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
    );
  }
}
