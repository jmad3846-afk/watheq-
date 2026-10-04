import '../../core/database/database_helper.dart';
import '../../domain/models/supplier.dart';

class SupplierRepository {
  Future<List<Supplier>> getAllSuppliers() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('suppliers', orderBy: 'name ASC');
    return maps.map((map) => Supplier.fromMap(map)).toList();
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  /// Calculates total outstanding payables ("علينا") owed to all suppliers.
  /// Total per invoice = items subtotal + delivery cost (when غير واصلة).
  Future<double> getTotalPayables() async {
    final db = await DatabaseHelper.instance.database;

    // Sum invoice totals (items + delivery when not delivered) minus payments.
    // Falls back to items-only query on legacy databases missing new columns.
    List<Map<String, Object?>> invRows;
    try {
      invRows = await db.rawQuery('''
        SELECT pi.id, pi.paid_amount,
          (SELECT COALESCE(SUM(pii.quantity * pii.unit_price * (CASE WHEN pii.is_return = 1 THEN -1 ELSE 1 END)), 0)
           FROM purchase_invoice_items pii WHERE pii.invoice_id = pi.id)
          + CASE WHEN COALESCE(pi.is_delivered, 1) = 0 THEN COALESCE(pi.delivery_cost, 0) ELSE 0 END as total
        FROM purchase_invoices pi
      ''');
    } catch (_) {
      invRows = await db.rawQuery('''
        SELECT pi.id, pi.paid_amount,
          (SELECT COALESCE(SUM(pii.quantity * pii.unit_price * (CASE WHEN pii.is_return = 1 THEN -1 ELSE 1 END)), 0)
           FROM purchase_invoice_items pii WHERE pii.invoice_id = pi.id) as total
        FROM purchase_invoices pi
      ''');
    }

    double totalPayables = 0.0;
    for (var row in invRows) {
      final total = (row['total'] as num? ?? 0).toDouble();
      final paid = (row['paid_amount'] as num? ?? 0).toDouble();
      final rem = total - paid;
      if (rem > 0) {
        totalPayables += rem;
      }
    }
    return totalPayables;
  }
}
