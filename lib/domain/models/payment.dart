class Payment {
  final int? id;
  final String entityType; // 'supplier' or 'client'
  final int entityId;
  final int? invoiceId;
  final double amount;
  final DateTime date;
  final String notes;

  const Payment({
    this.id,
    required this.entityType,
    required this.entityId,
    this.invoiceId,
    required this.amount,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'invoice_id': invoiceId,
      'amount': amount,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String,
      entityId: map['entity_id'] as int,
      invoiceId: map['invoice_id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      notes: map['notes'] as String? ?? '',
    );
  }
}
