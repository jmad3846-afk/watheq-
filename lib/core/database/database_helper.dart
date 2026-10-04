import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Database? _mockInMemoryDb;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (kIsWeb) {
      try {
        _database = await _initWebDatabase().timeout(const Duration(seconds: 3));
      } catch (e) {
        print('Web DB Timeout/Error, using fallback mock mode: $e');
        _database = await _getMockInMemoryDb();
      }
    } else {
      _database = await _initDesktopDatabase();
    }
    return _database!;
  }

  Future<Database> _initWebDatabase() async {
    databaseFactory = databaseFactoryFfiWeb;
    return await openDatabase(
      'wathaq_database.db',
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<Database> _initDesktopDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getApplicationDocumentsDirectory();
    final path = p.join(dbPath.path, 'WathaqData', 'wathaq_database.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<Database> _getMockInMemoryDb() async {
    if (_mockInMemoryDb != null) return _mockInMemoryDb!;
    _mockInMemoryDb = await openDatabase(
      ':memory:',
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
    return _mockInMemoryDb!;
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Products Table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0.0,
        unit TEXT NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0.0,
        sale_price REAL NOT NULL DEFAULT 0.0,
        low_stock_threshold REAL NOT NULL DEFAULT 5.0
      )
    ''');

    // 2. Suppliers Table (basic contact info only — no delivery fields)
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        location TEXT,
        items_sold TEXT,
        notes TEXT
      )
    ''');

    // 3. Clients Table
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        profession TEXT
      )
    ''');

    // 4. Purchase Invoices Table (includes delivery status per-invoice)
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL,
        supplier_name TEXT NOT NULL,
        date TEXT NOT NULL,
        image_path TEXT,
        notes TEXT,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        is_delivered INTEGER NOT NULL DEFAULT 1,
        driver_name TEXT,
        driver_phone TEXT,
        delivery_cost REAL NOT NULL DEFAULT 0.0,
        delivery_notes TEXT,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
      )
    ''');

    // 5. Purchase Invoice Items Table
    await db.execute('''
      CREATE TABLE purchase_invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit TEXT NOT NULL,
        is_return INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 6. Sale Invoices Table
    // type: 'regular' (standard cash), 'long' (legacy, treated as project),
    //   'project' (Approved Project invoice), 'return' (Return invoice).
    await db.execute('''
      CREATE TABLE sale_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        client_id INTEGER,
        client_name TEXT,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        deposit REAL NOT NULL DEFAULT 0.0,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        project_id INTEGER,
        project_name TEXT,
        is_return_invoice INTEGER NOT NULL DEFAULT 0,
        return_of_invoice_id INTEGER,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
        FOREIGN KEY (project_id) REFERENCES approved_projects (id) ON DELETE SET NULL,
        FOREIGN KEY (return_of_invoice_id) REFERENCES sale_invoices (id) ON DELETE SET NULL
      )
    ''');

    // 6b. Approved Projects Table (contractor projects)
    await db.execute('''
      CREATE TABLE approved_projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        client_name TEXT NOT NULL,
        location TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    // 7. Sale Invoice Items Table
    await db.execute('''
      CREATE TABLE sale_invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        unit TEXT NOT NULL,
        is_return INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id) REFERENCES sale_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 8. Payments Table
    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL, -- 'supplier' or 'client'
        entity_id INTEGER NOT NULL,
        invoice_id INTEGER,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');

    // 9. Invoice Counter Table (for Year-prefixed numbers: e.g. 2026-0001)
    await db.execute('''
      CREATE TABLE invoice_counters (
        year INTEGER NOT NULL,
        invoice_type TEXT NOT NULL, -- 'purchase' or 'sale'
        last_seq INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (year, invoice_type)
      )
    ''');
  }

  /// Migration v1 -> v2:
  /// - Remove delivery columns from suppliers (basic contact info only).
  /// - Add delivery status + driver columns to purchase_invoices.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Add delivery columns to purchase_invoices (guard each with try/catch
      //    so re-runs / partial upgrades don't crash).
      Future<void> addColumn(String sql) async {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column likely already exists — ignore.
        }
      }

      await addColumn(
          'ALTER TABLE purchase_invoices ADD COLUMN is_delivered INTEGER NOT NULL DEFAULT 1');
      await addColumn('ALTER TABLE purchase_invoices ADD COLUMN driver_name TEXT');
      await addColumn('ALTER TABLE purchase_invoices ADD COLUMN driver_phone TEXT');
      await addColumn(
          'ALTER TABLE purchase_invoices ADD COLUMN delivery_cost REAL NOT NULL DEFAULT 0.0');
      await addColumn('ALTER TABLE purchase_invoices ADD COLUMN delivery_notes TEXT');

      // 2. Drop delivery columns from suppliers where supported.
      //    Older SQLite versions don't support DROP COLUMN — ignore failures
      //    and just leave legacy columns unused (Supplier.fromMap ignores them).
      for (final col in [
        'delivery_arrived',
        'delivery_person',
        'delivery_phone',
        'delivery_cost'
      ]) {
        try {
          await db.execute('ALTER TABLE suppliers DROP COLUMN $col');
        } catch (_) {
          // Not supported or column missing — safe to ignore.
        }
      }
    }

    /// Migration v2 -> v3:
    /// - New `approved_projects` table (approved party + project location).
    /// - New columns on `sale_invoices`: project_id, project_name,
    ///   is_return_invoice, return_of_invoice_id.
    /// - Legacy `type = 'long'` rows are kept as-is and treated as
    ///   project-type invoices grouped under "بدون مشروع محدد".
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE approved_projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id INTEGER NOT NULL,
            client_name TEXT NOT NULL,
            location TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {
        // Table already exists — ignore.
      }

      Future<void> addSaleColumn(String sql) async {
        try {
          await db.execute(sql);
        } catch (_) {
          // Column likely already exists — ignore.
        }
      }

      await addSaleColumn(
          'ALTER TABLE sale_invoices ADD COLUMN project_id INTEGER');
      await addSaleColumn(
          'ALTER TABLE sale_invoices ADD COLUMN project_name TEXT');
      await addSaleColumn(
          'ALTER TABLE sale_invoices ADD COLUMN is_return_invoice INTEGER NOT NULL DEFAULT 0');
      await addSaleColumn(
          'ALTER TABLE sale_invoices ADD COLUMN return_of_invoice_id INTEGER');
    }
  }

  /// Generates next year-prefixed invoice number (e.g. 2026-0001) atomically.
  /// Standalone version — opens its own transaction. Do NOT call this from
  /// inside another `db.transaction` (sqflite does not support nesting and
  /// the save will throw, leaving the dialog stuck open).
  Future<String> generateNextInvoiceNumber(String type) async {
    final db = await database;
    return await db.transaction(
        (txn) => generateNextInvoiceNumberTx(txn, type));
  }

  /// Transaction-aware version — MUST be used when already inside a
  /// `db.transaction((txn) {...})` block (e.g. invoice creation).
  Future<String> generateNextInvoiceNumberTx(
      Transaction txn, String type) async {
    final year = DateTime.now().year;

    final res = await txn.query(
      'invoice_counters',
      where: 'year = ? AND invoice_type = ?',
      whereArgs: [year, type],
    );

    int nextSeq = 1;
    if (res.isNotEmpty) {
      nextSeq = (res.first['last_seq'] as int) + 1;
      await txn.update(
        'invoice_counters',
        {'last_seq': nextSeq},
        where: 'year = ? AND invoice_type = ?',
        whereArgs: [year, type],
      );
    } else {
      await txn.insert('invoice_counters', {
        'year': year,
        'invoice_type': type,
        'last_seq': 1,
      });
    }

    final seqStr = nextSeq.toString().padLeft(4, '0');
    return '$year-$seqStr';
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
