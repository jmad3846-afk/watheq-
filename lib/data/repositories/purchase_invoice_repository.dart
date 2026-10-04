import '../../core/database/database_helper.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/purchase_invoice.dart';
import 'product_repository.dart';

class PurchaseInvoiceRepository {
  final ProductRepository _productRepo = ProductRepository();

  Future<List<PurchaseInvoice>> getAllInvoices() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('purchase_invoices', orderBy: 'id DESC');

    List<PurchaseInvoice> list = [];
    for (var map in maps) {
      final invId = map['id'] as int;
      final itemMaps = await db.query('purchase_invoice_items', where: 'invoice_id = ?', whereArgs: [invId]);
      final items = itemMaps.map((im) => InvoiceItem.fromMap(im)).toList();
      list.add(PurchaseInvoice.fromMap(map, items: items));
    }
    return list;
  }

  Future<List<PurchaseInvoice>> getInvoicesBySupplier(int supplierId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('purchase_invoices', where: 'supplier_id = ?', whereArgs: [supplierId], orderBy: 'id DESC');

    List<PurchaseInvoice> list = [];
    for (var map in maps) {
      final invId = map['id'] as int;
      final itemMaps = await db.query('purchase_invoice_items', where: 'invoice_id = ?', whereArgs: [invId]);
      final items = itemMaps.map((im) => InvoiceItem.fromMap(im)).toList();
      list.add(PurchaseInvoice.fromMap(map, items: items));
    }
    return list;
  }

  Future<int> createInvoice(PurchaseInvoice invoice) async {
    final db = await DatabaseHelper.instance.database;

    return await db.transaction((txn) async {
      // Auto-generate invoice number if empty
      String invNum = invoice.invoiceNumber;
      if (invNum.isEmpty) {
        // Use the txn-aware version: we are already inside db.transaction,
        // a nested db.transaction() call would throw and abort the save.
        invNum = await DatabaseHelper.instance
            .generateNextInvoiceNumberTx(txn, 'purchase');
      }

      final invMap = invoice.copyWith(invoiceNumber: invNum).toMap();
      final invoiceId = await txn.insert('purchase_invoices', invMap);

      for (var item in invoice.items) {
        await txn.insert('purchase_invoice_items', item.toMap(invoiceId));

        // Adjust warehouse stock (+ for purchase, - for return)
        final qtyDelta = item.isReturn ? -item.quantity : item.quantity;
        await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      }

      // Record initial payment if > 0
      if (invoice.paidAmount > 0) {
        await txn.insert('payments', {
          'entity_type': 'supplier',
          'entity_id': invoice.supplierId,
          'invoice_id': invoiceId,
          'amount': invoice.paidAmount,
          'date': invoice.date.toIso8601String(),
          'notes': 'دفعة أولية للفاتورة $invNum',
        });
      }

      return invoiceId;
    });
  }

  /// Append-only edit: insert [newItems] into an existing purchase invoice
  /// without touching the header or existing lines. Adjusts warehouse
  /// stock (+ for purchase, - for return) like [createInvoice].
  Future<void> appendInvoiceItems(int invoiceId, List<InvoiceItem> newItems) async {
    if (newItems.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final head = await txn.query('purchase_invoices',
          where: 'id = ?', whereArgs: [invoiceId]);
      if (head.isEmpty) throw Exception('الفاتورة غير موجودة');
      for (var item in newItems) {
        await txn.insert('purchase_invoice_items', item.toMap(invoiceId));
        final qtyDelta = item.isReturn ? -item.quantity : item.quantity;
        await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      }
    });
  }

  /// Remove a single item line from an existing purchase invoice.
  /// Reverts exactly the stock movement that line caused at creation
  /// (inverse of [createInvoice]/[appendInvoiceItems]). Header, other
  /// lines and payments are left untouched.
  Future<void> removeInvoiceItem(int invoiceId, int itemId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final head = await txn.query('purchase_invoices',
          where: 'id = ?', whereArgs: [invoiceId]);
      if (head.isEmpty) throw Exception('الفاتورة غير موجودة');
      final itemMaps = await txn.query('purchase_invoice_items',
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
      if (itemMaps.isEmpty) throw Exception('الصنف غير موجود في الفاتورة');
      final item = InvoiceItem.fromMap(itemMaps.first);
      final qtyDelta = item.isReturn ? item.quantity : -item.quantity;
      await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      await txn.delete('purchase_invoice_items',
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
    });
  }

  /// Update the quantity of a single item line in an existing purchase
  /// invoice. Applies only the stock *difference*. Header, other lines
  /// and payments are left untouched.
  Future<void> updateInvoiceItemQty(
      int invoiceId, int itemId, double newQty) async {
    if (newQty <= 0) throw Exception('الكمية يجب أن تكون أكبر من صفر');
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final head = await txn.query('purchase_invoices',
          where: 'id = ?', whereArgs: [invoiceId]);
      if (head.isEmpty) throw Exception('الفاتورة غير موجودة');
      final itemMaps = await txn.query('purchase_invoice_items',
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
      if (itemMaps.isEmpty) throw Exception('الصنف غير موجود في الفاتورة');
      final item = InvoiceItem.fromMap(itemMaps.first);
      final diff = newQty - item.quantity;
      if (diff == 0) return;
      final stockDelta = item.isReturn ? -diff : diff;
      await _productRepo.adjustStock(txn, item.productId, stockDelta);
      await txn.update('purchase_invoice_items', {'quantity': newQty},
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
    });
  }

  Future<void> deleteInvoice(int invoiceId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      // Revert stock adjustments before deletion
      final itemMaps = await txn.query('purchase_invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
      for (var im in itemMaps) {
        final item = InvoiceItem.fromMap(im);
        final qtyDelta = item.isReturn ? item.quantity : -item.quantity;
        await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      }

      await txn.delete('purchase_invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
      await txn.delete('purchase_invoices', where: 'id = ?', whereArgs: [invoiceId]);
      await txn.delete('payments',
          where: 'invoice_id = ? AND entity_type = ?',
          whereArgs: [invoiceId, 'supplier']);
    });
  }
}
