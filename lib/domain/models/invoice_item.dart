class InvoiceItem {
  final int? id;
  final int? invoiceId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final String unit;
  final bool isReturn;

  const InvoiceItem({
    this.id,
    this.invoiceId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
    this.isReturn = false,
  });

  double get subtotal => (isReturn ? -1 : 1) * (quantity * unitPrice);

  InvoiceItem copyWith({
    int? id,
    int? invoiceId,
    int? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    String? unit,
    bool? isReturn,
  }) {
    return InvoiceItem(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      isReturn: isReturn ?? this.isReturn,
    );
  }

  Map<String, dynamic> toMap(int parentInvoiceId) {
    return {
      if (id != null) 'id': id,
      'invoice_id': parentInvoiceId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit': unit,
      'is_return': isReturn ? 1 : 0,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as int?,
      invoiceId: map['invoice_id'] as int?,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String? ?? '',
      quantity: (map['quantity'] as num).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      unit: map['unit'] as String? ?? '',
      isReturn: (map['is_return'] as int? ?? 0) == 1,
    );
  }
}
