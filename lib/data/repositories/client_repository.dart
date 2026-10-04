import '../../core/database/database_helper.dart';
import '../../domain/models/client.dart';

class ClientRepository {
  Future<List<Client>> getAllClients() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('clients', orderBy: 'name ASC');
    return maps.map((map) => Client.fromMap(map)).toList();
  }

  Future<int> insertClient(Client client) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('clients', client.toMap());
  }

  Future<int> updateClient(Client client) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'clients',
      client.toMap(),
      where: 'id = ?',
      whereArgs: [client.id],
    );
  }

  Future<int> deleteClient(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  /// Calculates total outstanding receivables ("لنا") — PROJECTS ONLY.
  /// Standard (cash) sales are settled immediately and never count here.
  /// Σ(project + legacy-long invoice totals − paid) − Σ(return totals).
  /// Return invoices deduct from the balance without touching originals.
  Future<double> getTotalReceivables() async {
    final db = await DatabaseHelper.instance.database;

    List<Map<String, Object?>> invRows;
    try {
      invRows = await db.rawQuery('''
        SELECT si.id, si.paid_amount, si.project_id,
          COALESCE(si.is_return_invoice, 0) as is_ret,
          si.type as inv_type,
          (SELECT COALESCE(SUM(sii.quantity * sii.unit_price * (CASE WHEN sii.is_return = 1 THEN -1 ELSE 1 END)), 0)
           FROM sale_invoice_items sii WHERE sii.invoice_id = si.id) as total
        FROM sale_invoices si
        WHERE (COALESCE(si.is_return_invoice, 0) = 0
          AND (si.project_id IS NOT NULL OR si.type = 'long'))
          OR COALESCE(si.is_return_invoice, 0) = 1
      ''');
    } catch (_) {
      // Legacy database without new columns: fall back to all non-return rows.
      invRows = await db.rawQuery('''
        SELECT si.id, si.paid_amount,
          NULL as project_id,
          0 as is_ret,
          si.type as inv_type,
          (SELECT COALESCE(SUM(sii.quantity * sii.unit_price * (CASE WHEN sii.is_return = 1 THEN -1 ELSE 1 END)), 0)
           FROM sale_invoice_items sii WHERE sii.invoice_id = si.id) as total
        FROM sale_invoices si
      ''');
    }

    double issued = 0.0;
    double paid = 0.0;
    double returns = 0.0;
    for (var row in invRows) {
      final total = (row['total'] as num? ?? 0).toDouble();
      final p = (row['paid_amount'] as num? ?? 0).toDouble();
      final isRet = ((row['is_ret'] as num? ?? 0).toInt() == 1) ||
          (row['inv_type'] as String?) == 'return' ||
          (row['inv_type'] as String?) == 'ret';
      if (isRet) {
        returns += total;
      } else {
        issued += total;
        paid += p;
      }
    }
    final net = issued - paid - returns;
    return net > 0 ? net : 0.0;
  }
}
