import '../../core/database/database_helper.dart';
import '../../domain/models/invoice_item.dart';
import '../../domain/models/sale_invoice.dart';
import 'product_repository.dart';

class SaleInvoiceRepository {
  final ProductRepository _productRepo = ProductRepository();

  Future<List<SaleInvoice>> getAllInvoices({SaleInvoiceType? typeFilter}) async {
    final db = await DatabaseHelper.instance.database;
    final where = typeFilter != null ? 'type = ?' : null;
    final whereArgs = typeFilter != null ? [typeFilter.name] : null;

    final maps = await db.query('sale_invoices', where: where, whereArgs: whereArgs, orderBy: 'id DESC');

    List<SaleInvoice> list = [];
    for (var map in maps) {
      final invId = map['id'] as int;
      final itemMaps = await db.query('sale_invoice_items', where: 'invoice_id = ?', whereArgs: [invId]);
      final items = itemMaps.map((im) => InvoiceItem.fromMap(im)).toList();
      list.add(SaleInvoice.fromMap(map, items: items));
    }
    return list;
  }

  Future<List<SaleInvoice>> getInvoicesByClient(int clientId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('sale_invoices', where: 'client_id = ?', whereArgs: [clientId], orderBy: 'id DESC');

    List<SaleInvoice> list = [];
    for (var map in maps) {
      final invId = map['id'] as int;
      final itemMaps = await db.query('sale_invoice_items', where: 'invoice_id = ?', whereArgs: [invId]);
      final items = itemMaps.map((im) => InvoiceItem.fromMap(im)).toList();
      list.add(SaleInvoice.fromMap(map, items: items));
    }
    return list;
  }

  Future<int> createInvoice(SaleInvoice invoice) async {
    final db = await DatabaseHelper.instance.database;

    return await db.transaction((txn) async {
      String invNum = invoice.invoiceNumber;
      if (invNum.isEmpty) {
        // Use the txn-aware version: we are already inside db.transaction,
        // a nested db.transaction() call would throw and abort the save.
        invNum = await DatabaseHelper.instance
            .generateNextInvoiceNumberTx(txn, 'sale');
      }

      final bool isReturn = invoice.isReturnInvoice ||
          invoice.type == SaleInvoiceType.salesReturn;

      // For regular cash sales, paidAmount equals totalAmount automatically.
      // Return invoices never carry a payment (they deduct from the balance).
      double initialPaid = invoice.paidAmount;
      if (!isReturn) {
        if (invoice.type == SaleInvoiceType.regular && initialPaid == 0) {
          initialPaid = invoice.totalAmount;
        } else if ((invoice.type == SaleInvoiceType.long ||
                invoice.type == SaleInvoiceType.project) &&
            initialPaid == 0 &&
            invoice.deposit > 0) {
          initialPaid = invoice.deposit;
        }
      } else {
        initialPaid = 0.0;
      }

      final invMap = invoice
          .copyWith(
            invoiceNumber: invNum,
            paidAmount: initialPaid,
            isReturnInvoice: isReturn,
            type: isReturn ? SaleInvoiceType.salesReturn : invoice.type,
          )
          .toMap();

      final invoiceId = await txn.insert('sale_invoices', invMap);

      for (var item in invoice.items) {
        await txn.insert('sale_invoice_items', item.toMap(invoiceId));

        // Stock: sales remove stock, returns put goods back to inventory.
        // (Line-level isReturn still supported for legacy rows.)
        double qtyDelta;
        if (isReturn) {
          qtyDelta = item.quantity;
        } else {
          qtyDelta = item.isReturn ? item.quantity : -item.quantity;
        }
        await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      }

      // Record payment transaction if client ID exists and payment > 0.
      // Never for return invoices. The original invoice stays untouched —
      // the return value is deducted at balance-computation time.
      if (!isReturn && invoice.clientId != null && initialPaid > 0) {
        await txn.insert('payments', {
          'entity_type': 'client',
          'entity_id': invoice.clientId,
          'invoice_id': invoiceId,
          'amount': initialPaid,
          'date': invoice.date.toIso8601String(),
          'notes': 'دفعة/تسديد للفاتورة $invNum',
        });
      }

      return invoiceId;
    });
  }

  /// Append-only edit: insert [newItems] into an existing invoice without
  /// touching the header (number/date/client/paid) or existing lines.
  /// Adjusts stock exactly like [createInvoice] (sales decrement,
  /// returns increment). Totals are derived from items, so they update
  /// automatically on the next load.
  Future<void> appendInvoiceItems(int invoiceId, List<InvoiceItem> newItems) async {
    if (newItems.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final head =
          await txn.query('sale_invoices', where: 'id = ?', whereArgs: [invoiceId]);
      if (head.isEmpty) throw Exception('الفاتورة غير موجودة');
      final row = head.first;
      final bool isReturn = ((row['is_return_invoice'] as num? ?? 0).toInt() == 1) ||
          (row['type'] as String?) == 'return' ||
          (row['type'] as String?) == 'ret';

      for (var item in newItems) {
        await txn.insert('sale_invoice_items', item.toMap(invoiceId));
        double qtyDelta;
        if (isReturn) {
          qtyDelta = item.quantity;
        } else {
          qtyDelta = item.isReturn ? item.quantity : -item.quantity;
        }
        await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      }
    });
  }

  /// Remove a single item line from an existing sale invoice.
  /// Reverts exactly the stock movement that line caused at creation
  /// (inverse of [createInvoice]/[appendInvoiceItems]). Header, other
  /// lines and payments are left untouched.
  Future<void> removeInvoiceItem(int invoiceId, int itemId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final head =
          await txn.query('sale_invoices', where: 'id = ?', whereArgs: [invoiceId]);
      if (head.isEmpty) throw Exception('الفاتورة غير موجودة');
      final row = head.first;
      final bool isReturn = ((row['is_return_invoice'] as num? ?? 0).toInt() == 1) ||
          (row['type'] as String?) == 'return' ||
          (row['type'] as String?) == 'ret';

      final itemMaps = await txn.query('sale_invoice_items',
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
      if (itemMaps.isEmpty) throw Exception('الصنف غير موجود في الفاتورة');
      final item = InvoiceItem.fromMap(itemMaps.first);

      double qtyDelta;
      if (isReturn) {
        qtyDelta = -item.quantity;
      } else {
        qtyDelta = item.isReturn ? -item.quantity : item.quantity;
      }
      await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      await txn.delete('sale_invoice_items',
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
    });
  }

  /// Update the quantity of a single item line in an existing sale invoice.
  /// Applies only the stock *difference* (inverse-aware like the other
  /// methods). Header, other lines and payments are left untouched.
  Future<void> updateInvoiceItemQty(
      int invoiceId, int itemId, double newQty) async {
    if (newQty <= 0) throw Exception('الكمية يجب أن تكون أكبر من صفر');
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      final head =
          await txn.query('sale_invoices', where: 'id = ?', whereArgs: [invoiceId]);
      if (head.isEmpty) throw Exception('الفاتورة غير موجودة');
      final row = head.first;
      final bool isReturn = ((row['is_return_invoice'] as num? ?? 0).toInt() == 1) ||
          (row['type'] as String?) == 'return' ||
          (row['type'] as String?) == 'ret';

      final itemMaps = await txn.query('sale_invoice_items',
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
      if (itemMaps.isEmpty) throw Exception('الصنف غير موجود في الفاتورة');
      final item = InvoiceItem.fromMap(itemMaps.first);

      final diff = newQty - item.quantity;
      if (diff == 0) return;
      double stockDelta;
      if (isReturn) {
        stockDelta = diff;
      } else {
        stockDelta = item.isReturn ? diff : -diff;
      }
      await _productRepo.adjustStock(txn, item.productId, stockDelta);
      await txn.update('sale_invoice_items', {'quantity': newQty},
          where: 'id = ? AND invoice_id = ?', whereArgs: [itemId, invoiceId]);
    });
  }

  Future<void> deleteInvoice(int invoiceId) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      // Detect return invoices: deleting one takes the restocked goods back out.
      bool isReturn = false;
      final head =
          await txn.query('sale_invoices', where: 'id = ?', whereArgs: [invoiceId]);
      if (head.isNotEmpty) {
        final row = head.first;
        isReturn = ((row['is_return_invoice'] as num? ?? 0).toInt() == 1) ||
            (row['type'] as String?) == 'return' ||
            (row['type'] as String?) == 'ret';
      }

      // Revert stock adjustments
      final itemMaps = await txn.query('sale_invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
      for (var im in itemMaps) {
        final item = InvoiceItem.fromMap(im);
        double qtyDelta;
        if (isReturn) {
          qtyDelta = -item.quantity;
        } else {
          qtyDelta = item.isReturn ? -item.quantity : item.quantity;
        }
        await _productRepo.adjustStock(txn, item.productId, qtyDelta);
      }

      await txn.delete('sale_invoice_items', where: 'invoice_id = ?', whereArgs: [invoiceId]);
      await txn.delete('sale_invoices', where: 'id = ?', whereArgs: [invoiceId]);
      await txn.delete('payments',
          where: 'invoice_id = ? AND entity_type = ?',
          whereArgs: [invoiceId, 'client']);
    });
  }
}
