import 'invoice_item.dart';

class PurchaseInvoice {
  final int? id;
  final String invoiceNumber;
  final int supplierId;
  final String supplierName;
  final DateTime date;
  final String? imagePath;
  final String notes;
  final double paidAmount;
  final List<InvoiceItem> items;

  /// Delivery status: true = واصلة, false = غير واصلة (في الطريق)
  final bool isDelivered;

  /// Driver / delivery details attached to this specific invoice.
  final String? driverName;
  final String? driverPhone;
  final double deliveryCost;
  final String deliveryNotes;

  const PurchaseInvoice({
    this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.supplierName,
    required this.date,
    this.imagePath,
    this.notes = '',
    this.paidAmount = 0.0,
    this.items = const [],
    this.isDelivered = true,
    this.driverName,
    this.driverPhone,
    this.deliveryCost = 0.0,
    this.deliveryNotes = '',
  });

  /// Sum of item lines only (without delivery).
  double get subtotal {
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Effective delivery cost: 0 when goods already arrived (واصلة).
  double get effectiveDeliveryCost {
    if (isDelivered) return 0.0;
    if (deliveryCost.isNaN || deliveryCost < 0) return 0.0;
    return deliveryCost;
  }

  /// Grand total: Total = Subtotal + deliveryCost (when غير واصلة).
  double get totalAmount {
    return subtotal + effectiveDeliveryCost;
  }

  double get remainingBalance => totalAmount - paidAmount;

  bool get isFullyPaid => remainingBalance <= 0.01;

  PurchaseInvoice copyWith({
    int? id,
    String? invoiceNumber,
    int? supplierId,
    String? supplierName,
    DateTime? date,
    String? imagePath,
    String? notes,
    double? paidAmount,
    List<InvoiceItem>? items,
    bool? isDelivered,
    String? driverName,
    String? driverPhone,
    double? deliveryCost,
    String? deliveryNotes,
  }) {
    return PurchaseInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      date: date ?? this.date,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
      paidAmount: paidAmount ?? this.paidAmount,
      items: items ?? this.items,
      isDelivered: isDelivered ?? this.isDelivered,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      deliveryCost: deliveryCost ?? this.deliveryCost,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'supplier_id': supplierId,
      'supplier_name': supplierName,
      'date': date.toIso8601String(),
      'image_path': imagePath,
      'notes': notes,
      'paid_amount': paidAmount,
      'is_delivered': isDelivered ? 1 : 0,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'delivery_cost': deliveryCost,
      'delivery_notes': deliveryNotes,
    };
  }

  factory PurchaseInvoice.fromMap(
    Map<String, dynamic> map, {
    List<InvoiceItem> items = const [],
  }) {
    return PurchaseInvoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      supplierId: map['supplier_id'] as int,
      supplierName: map['supplier_name'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      imagePath: map['image_path'] as String?,
      notes: map['notes'] as String? ?? '',
      paidAmount: (map['paid_amount'] as num? ?? 0).toDouble(),
      items: items,
      isDelivered: (map['is_delivered'] as int? ?? 1) == 1,
      driverName: map['driver_name'] as String?,
      driverPhone: map['driver_phone'] as String?,
      deliveryCost: (map['delivery_cost'] as num? ?? 0).toDouble(),
      deliveryNotes: map['delivery_notes'] as String? ?? '',
    );
  }
}
