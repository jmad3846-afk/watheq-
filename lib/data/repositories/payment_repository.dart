import '../../core/database/database_helper.dart';
import '../../domain/models/payment.dart';

class PaymentRepository {
  Future<List<Payment>> getPaymentsForEntity(String entityType, int entityId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'payments',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'id DESC',
    );
    return maps.map((map) => Payment.fromMap(map)).toList();
  }

  /// All recorded payments, newest first — used for per-person history.
  Future<List<Payment>> getAllPayments() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('payments', orderBy: 'id DESC');
    return maps.map((map) => Payment.fromMap(map)).toList();
  }

  /// The most recent payment for one person (null when never paid).
  Future<Payment?> getLastPayment(String entityType, int entityId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'payments',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Payment.fromMap(maps.first);
  }

  Future<int> recordPayment({
    required String entityType,
    required int entityId,
    required double amount,
    int? invoiceId,
    String notes = '',
  }) async {
    final db = await DatabaseHelper.instance.database;

    return await db.transaction((txn) async {
      // 1. Insert payment row
      final paymentId = await txn.insert('payments', {
        'entity_type': entityType,
        'entity_id': entityId,
        'invoice_id': invoiceId,
        'amount': amount,
        'date': DateTime.now().toIso8601String(),
        'notes': notes,
      });

      // 2. If tied to a specific invoice, deduct/update paid_amount
      if (invoiceId != null) {
        if (entityType == 'supplier') {
          final invRows = await txn.query('purchase_invoices', where: 'id = ?', whereArgs: [invoiceId]);
          if (invRows.isNotEmpty) {
            final currentPaid = (invRows.first['paid_amount'] as num? ?? 0).toDouble();
            await txn.update(
              'purchase_invoices',
              {'paid_amount': currentPaid + amount},
              where: 'id = ?',
              whereArgs: [invoiceId],
            );
          }
        } else if (entityType == 'client') {
          final invRows = await txn.query('sale_invoices', where: 'id = ?', whereArgs: [invoiceId]);
          if (invRows.isNotEmpty) {
            final currentPaid = (invRows.first['paid_amount'] as num? ?? 0).toDouble();
            await txn.update(
              'sale_invoices',
              {'paid_amount': currentPaid + amount},
              where: 'id = ?',
              whereArgs: [invoiceId],
            );
          }
        }
      } else {
        // Distribute payment across oldest unpaid invoices.
        // Return invoices never receive payments (they deduct from balance).
        double remainingAmount = amount;
        final table = entityType == 'supplier' ? 'purchase_invoices' : 'sale_invoices';
        final fk = entityType == 'supplier' ? 'supplier_id' : 'client_id';

        List<Map<String, Object?>> invRows;
        if (entityType == 'client') {
          try {
            invRows = await txn.query(table,
                where:
                    '$fk = ? AND COALESCE(is_return_invoice, 0) = 0 AND type != ?',
                whereArgs: [entityId, 'return'],
                orderBy: 'id ASC');
          } catch (_) {
            // Legacy database without new columns — fall back.
            invRows = await txn.query(table,
                where: '$fk = ?', whereArgs: [entityId], orderBy: 'id ASC');
          }
        } else {
          invRows = await txn.query(table,
              where: '$fk = ?', whereArgs: [entityId], orderBy: 'id ASC');
        }

        for (var row in invRows) {
          if (remainingAmount <= 0) break;

          final id = row['id'] as int;
          final currentPaid = (row['paid_amount'] as num? ?? 0).toDouble();

          // Calculate total for this invoice (items ± returns).
          final itemsTable = entityType == 'supplier' ? 'purchase_invoice_items' : 'sale_invoice_items';
          final totals = await txn.rawQuery('''
            SELECT COALESCE(SUM(quantity * unit_price * (CASE WHEN is_return = 1 THEN -1 ELSE 1 END)), 0) as total
            FROM $itemsTable WHERE invoice_id = ?
          ''', [id]);

          double total = (totals.first['total'] as num? ?? 0).toDouble();

          // Supplier invoices may carry a delivery cost when goods are
          // undelivered — include it so allocation matches the real balance.
          if (entityType == 'supplier') {
            try {
              final head = await txn.query(
                'purchase_invoices',
                columns: ['is_delivered', 'delivery_cost'],
                where: 'id = ?',
                whereArgs: [id],
              );
              if (head.isNotEmpty) {
                final delivered =
                    ((head.first['is_delivered'] as num? ?? 1).toInt() ==
                        1);
                if (!delivered) {
                  total +=
                      (head.first['delivery_cost'] as num? ?? 0).toDouble();
                }
              }
            } catch (_) {
              // Legacy database — items total only.
            }
          }

          final rem = total - currentPaid;

          if (rem > 0) {
            final payForThis = remainingAmount > rem ? rem : remainingAmount;
            await txn.update(
              table,
              {'paid_amount': currentPaid + payForThis},
              where: 'id = ?',
              whereArgs: [id],
            );
            remainingAmount -= payForThis;
          }
        }
      }

      return paymentId;
    });
  }
}
