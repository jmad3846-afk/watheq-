import 'invoice_item.dart';

/// Sale invoice types:
/// - [regular]: standard (cash) sale.
/// - [project]: invoice issued to an Approved Project (replaces legacy long).
/// - [long]: legacy long-term invoice — read-only compat, treated as project.
/// - [ret]: Return invoice for an Approved Contractor Project. The original
///   invoice is never modified; the return row carries the returned items and
///   its value is deducted from the project balance while goods go back
///   to inventory.
enum SaleInvoiceType { regular, project, long, salesReturn }

SaleInvoiceType saleInvoiceTypeFromString(String? raw) {
  switch (raw) {
    case 'project':
      return SaleInvoiceType.project;
    case 'long':
      return SaleInvoiceType.long;
    case 'return':
    case 'ret':
    case 'salesReturn':
      return SaleInvoiceType.salesReturn;
    case 'regular':
    default:
      return SaleInvoiceType.regular;
  }
}

extension SaleInvoiceTypeX on SaleInvoiceType {
  String get dbName {
    switch (this) {
      case SaleInvoiceType.project:
        return 'project';
      case SaleInvoiceType.long:
        return 'long';
      case SaleInvoiceType.salesReturn:
        return 'return';
      case SaleInvoiceType.regular:
        return 'regular';
    }
  }

  String get arabicLabel {
    switch (this) {
      case SaleInvoiceType.project:
        return 'مشروع معتمد';
      case SaleInvoiceType.long:
        return 'طويلة (قديمة)';
      case SaleInvoiceType.salesReturn:
        return 'إرجاع';
      case SaleInvoiceType.regular:
        return 'عادية';
    }
  }
}

class SaleInvoice {
  final int? id;
  final String invoiceNumber;
  final int? clientId;
  final String? clientName;
  final SaleInvoiceType type;
  final DateTime date;
  final double deposit;
  final double paidAmount;
  final String notes;
  final List<InvoiceItem> items;

  /// Approved Project linkage (null = not linked to a project).
  final int? projectId;
  final String? projectName;

  /// True for Return invoices (also stored as type 'return').
  final bool isReturnInvoice;

  /// Original invoice id this return refers to (null when not a return).
  final int? returnOfInvoiceId;

  const SaleInvoice({
    this.id,
    required this.invoiceNumber,
    this.clientId,
    this.clientName,
    required this.type,
    required this.date,
    this.deposit = 0.0,
    this.paidAmount = 0.0,
    this.notes = '',
    this.items = const [],
    this.projectId,
    this.projectName,
    this.isReturnInvoice = false,
    this.returnOfInvoiceId,
  });

  double get totalAmount {
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  double get remainingBalance => totalAmount - paidAmount;

  bool get isFullyPaid => remainingBalance <= 0.01;

  /// Legacy long-term rows behave like project invoices.
  bool get isProjectLike =>
      type == SaleInvoiceType.project || type == SaleInvoiceType.long;

  bool get isStandard => type == SaleInvoiceType.regular;

  SaleInvoice copyWith({
    int? id,
    String? invoiceNumber,
    int? clientId,
    String? clientName,
    SaleInvoiceType? type,
    DateTime? date,
    double? deposit,
    double? paidAmount,
    String? notes,
    List<InvoiceItem>? items,
    int? projectId,
    String? projectName,
    bool? isReturnInvoice,
    int? returnOfInvoiceId,
  }) {
    return SaleInvoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      type: type ?? this.type,
      date: date ?? this.date,
      deposit: deposit ?? this.deposit,
      paidAmount: paidAmount ?? this.paidAmount,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      isReturnInvoice: isReturnInvoice ?? this.isReturnInvoice,
      returnOfInvoiceId: returnOfInvoiceId ?? this.returnOfInvoiceId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'client_id': clientId,
      'client_name': clientName,
      'type': type.dbName,
      'date': date.toIso8601String(),
      'deposit': deposit,
      'paid_amount': paidAmount,
      'notes': notes,
      'project_id': projectId,
      'project_name': projectName,
      'is_return_invoice': isReturnInvoice ? 1 : 0,
      'return_of_invoice_id': returnOfInvoiceId,
    };
  }

  factory SaleInvoice.fromMap(
    Map<String, dynamic> map, {
    List<InvoiceItem> items = const [],
  }) {
    final flag = (map['is_return_invoice'] as num? ?? 0).toInt() == 1;
    final parsed = saleInvoiceTypeFromString(map['type'] as String?);
    return SaleInvoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      clientId: map['client_id'] as int?,
      clientName: map['client_name'] as String?,
      type: flag ? SaleInvoiceType.salesReturn : parsed,
      date: DateTime.parse(map['date'] as String),
      deposit: (map['deposit'] as num? ?? 0).toDouble(),
      paidAmount: (map['paid_amount'] as num? ?? 0).toDouble(),
      notes: map['notes'] as String? ?? '',
      items: items,
      projectId: map['project_id'] as int?,
      projectName: map['project_name'] as String?,
      isReturnInvoice: flag,
      returnOfInvoiceId: map['return_of_invoice_id'] as int?,
    );
  }
}
