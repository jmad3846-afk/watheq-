import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../domain/models/product.dart';

class ProductRepository {
  Future<List<Product>> getAllProducts() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertProduct(Product product) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await DatabaseHelper.instance.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> adjustStock(Transaction txn, int productId, double qtyDelta) async {
    final res = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
    if (res.isNotEmpty) {
      final currentQty = (res.first['quantity'] as num).toDouble();
      final newQty = currentQty + qtyDelta;
      await txn.update(
        'products',
        {'quantity': newQty},
        where: 'id = ?',
        whereArgs: [productId],
      );
    }
  }
}
