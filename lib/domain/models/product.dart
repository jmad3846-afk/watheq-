class Product {
  final int? id;
  final String name;
  final double quantity;
  final String unit; // e.g., كغ, قطعة, صندوق
  final double costPrice;
  final double salePrice;
  final double lowStockThreshold;

  const Product({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.costPrice,
    required this.salePrice,
    required this.lowStockThreshold,
  });

  bool get isLowStock => quantity <= lowStockThreshold;

  Product copyWith({
    int? id,
    String? name,
    double? quantity,
    String? unit,
    double? costPrice,
    double? salePrice,
    double? lowStockThreshold,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      salePrice: salePrice ?? this.salePrice,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'cost_price': costPrice,
      'sale_price': salePrice,
      'low_stock_threshold': lowStockThreshold,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unit: map['unit'] as String,
      costPrice: (map['cost_price'] as num).toDouble(),
      salePrice: (map['sale_price'] as num).toDouble(),
      lowStockThreshold: (map['low_stock_threshold'] as num?)?.toDouble() ?? 5.0,
    );
  }
}
