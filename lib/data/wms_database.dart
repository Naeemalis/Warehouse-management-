import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class WmsDatabase {
  WmsDatabase._();
  static final WmsDatabase instance = WmsDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, 'naeemsoft_wms.db'),
      version: 1,
      onCreate: _createSchema,
      onConfigure: (db) async { await db.execute('PRAGMA foreign_keys = ON'); },
    );
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT UNIQUE,
      name TEXT NOT NULL,
      category TEXT,
      base_unit_name TEXT NOT NULL,
      tracking_mode TEXT NOT NULL DEFAULT 'count' CHECK(tracking_mode IN ('count','weight','volume')),
      purchase_price_minor INTEGER NOT NULL DEFAULT 0,
      issue_price_minor INTEGER NOT NULL DEFAULT 0,
      min_stock_base REAL NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE product_units (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES products(id),
      unit_name TEXT NOT NULL,
      factor_to_base REAL NOT NULL CHECK(factor_to_base > 0),
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      UNIQUE(product_id, unit_name)
    )''');
    await db.execute('''CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT,
      address TEXT, notes TEXT, is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, phone TEXT,
      address TEXT, notes TEXT, is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_no TEXT NOT NULL UNIQUE,
      kind TEXT NOT NULL CHECK(kind IN ('receipt','issue','transfer','return_in','return_out','adjustment')),
      status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','pending_approval','approved','rejected','cancelled')),
      party_type TEXT CHECK(party_type IN ('supplier','customer','department','warehouse')),
      party_id INTEGER, party_name_snapshot TEXT, notes TEXT,
      created_by INTEGER, created_at TEXT NOT NULL, submitted_at TEXT,
      approved_by INTEGER, approved_at TEXT, rejection_reason TEXT,
      delivery_status TEXT NOT NULL DEFAULT 'not_ready' CHECK(delivery_status IN ('not_ready','awaiting_delivery','delivered','partially_delivered')),
      delivered_by INTEGER, delivered_at TEXT, recipient_name TEXT, recipient_signature_note TEXT
    )''');
    await db.execute('''CREATE TABLE document_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      product_name_snapshot TEXT NOT NULL, unit_name_snapshot TEXT NOT NULL,
      entered_quantity REAL NOT NULL CHECK(entered_quantity > 0),
      factor_to_base_snapshot REAL NOT NULL CHECK(factor_to_base_snapshot > 0),
      base_quantity REAL NOT NULL CHECK(base_quantity > 0),
      unit_price_minor INTEGER NOT NULL DEFAULT 0,
      packaging_note TEXT, created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE stock_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
      document_line_id INTEGER NOT NULL REFERENCES document_lines(id) ON DELETE RESTRICT,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      direction TEXT NOT NULL CHECK(direction IN ('IN','OUT')),
      quantity_base REAL NOT NULL CHECK(quantity_base > 0),
      created_by INTEGER, created_at TEXT NOT NULL,
      UNIQUE(document_line_id)
    )''');
    await db.execute('''CREATE TABLE approval_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
      action TEXT NOT NULL CHECK(action IN ('submitted','approved','rejected','cancelled')),
      actor_id INTEGER, actor_name_snapshot TEXT, notes TEXT, created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE audit_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL,
      entity_id INTEGER NOT NULL, action TEXT NOT NULL, actor_id INTEGER,
      details TEXT, created_at TEXT NOT NULL
    )''');
    await db.execute('CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)');
    await db.execute('CREATE INDEX idx_product_units_product ON product_units(product_id)');
    await db.execute('CREATE INDEX idx_documents_status ON documents(status, kind)');
    await db.execute('CREATE INDEX idx_document_lines_document ON document_lines(document_id)');
    await db.execute('CREATE INDEX idx_movements_product ON stock_movements(product_id, created_at)');
    await db.insert('app_settings', {'setting_key': 'language', 'setting_value': 'ar'});
  }

  Future<double> getAvailableStock(int productId) async {
    final db = await database;
    final rows = await db.rawQuery('''SELECT COALESCE(SUM(CASE
      WHEN direction = 'IN' THEN quantity_base ELSE -quantity_base END), 0) AS balance
      FROM stock_movements WHERE product_id = ?''', [productId]);
    return (rows.first['balance'] as num?)?.toDouble() ?? 0;
  }

  // Only pending documents can be approved. Posting and status transition are atomic.
  Future<void> approveDocument({required int documentId, required int approverId}) async {
    final db = await database;
    await db.transaction((txn) async {
      final docs = await txn.query('documents', where: 'id = ?', whereArgs: [documentId], limit: 1);
      if (docs.isEmpty) throw StateError('Document not found');
      final doc = docs.first;
      if (doc['status'] != 'pending_approval') throw StateError('Only pending documents can be approved');
      final kind = doc['kind'] as String;
      if (kind != 'receipt' && kind != 'issue') throw StateError('Unsupported document kind in this milestone');
      final lines = await txn.query('document_lines', where: 'document_id = ?', whereArgs: [documentId]);
      if (lines.isEmpty) throw StateError('Cannot approve an empty document');
      if (kind == 'issue') {
        // Aggregate repeated product lines (e.g. carton + pack + piece)
        // before validating; checking each line independently can overspend.
        final requestedByProduct = <int, double>{};
        final nameByProduct = <int, String>{};
        for (final line in lines) {
          final productId = line['product_id'] as int;
          requestedByProduct.update(
            productId,
            (current) => current + (line['base_quantity'] as num).toDouble(),
            ifAbsent: () => (line['base_quantity'] as num).toDouble(),
          );
          nameByProduct[productId] = line['product_name_snapshot'] as String;
        }
        for (final entry in requestedByProduct.entries) {
          final rows = await txn.rawQuery('''SELECT COALESCE(SUM(CASE
            WHEN direction = 'IN' THEN quantity_base ELSE -quantity_base END), 0) AS balance
            FROM stock_movements WHERE product_id = ?''', [entry.key]);
          final balance = (rows.first['balance'] as num).toDouble();
          if (entry.value > balance) {
            throw StateError('Insufficient stock for ${nameByProduct[entry.key]}');
          }
        }
      }
      final now = DateTime.now().toIso8601String();
      for (final line in lines) {
        await txn.insert('stock_movements', {
          'document_id': documentId, 'document_line_id': line['id'],
          'product_id': line['product_id'], 'direction': kind == 'receipt' ? 'IN' : 'OUT',
          'quantity_base': line['base_quantity'], 'created_by': approverId, 'created_at': now,
        });
      }
      await txn.update('documents', {
        'status': 'approved', 'approved_by': approverId, 'approved_at': now,
        'delivery_status': kind == 'issue' ? 'awaiting_delivery' : 'not_ready',
      }, where: 'id = ?', whereArgs: [documentId]);
      await txn.insert('approval_history', {
        'document_id': documentId, 'action': 'approved', 'actor_id': approverId,
        'actor_name_snapshot': 'User #$approverId', 'created_at': now,
      });
    });
  }

  Future<void> confirmDelivery({required int documentId, required int userId, required String recipientName, String? signatureNote}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('documents', where: 'id = ?', whereArgs: [documentId], limit: 1);
      if (rows.isEmpty) throw StateError('Document not found');
      final doc = rows.first;
      if (doc['kind'] != 'issue' || doc['status'] != 'approved') throw StateError('Only approved issue documents can be delivered');
      if (doc['delivery_status'] == 'delivered') throw StateError('Already delivered');
      await txn.update('documents', {
        'delivery_status': 'delivered', 'delivered_by': userId,
        'delivered_at': DateTime.now().toIso8601String(),
        'recipient_name': recipientName, 'recipient_signature_note': signatureNote,
      }, where: 'id = ?', whereArgs: [documentId]);
    });
  }
}


extension WmsCatalogOperations on WmsDatabase {
  Future<List<Map<String, Object?>>> listProducts() async {
    final db = await database;
    return db.rawQuery('''
      SELECT p.*,
        COALESCE((SELECT SUM(CASE WHEN m.direction='IN' THEN m.quantity_base ELSE -m.quantity_base END)
          FROM stock_movements m WHERE m.product_id=p.id),0) AS stock_base
      FROM products p WHERE p.is_active=1 ORDER BY p.name COLLATE NOCASE
    ''');
  }

  Future<List<Map<String, Object?>>> listUnits(int productId) async {
    final db = await database;
    return db.query('product_units', where: 'product_id=? AND is_active=1',
      whereArgs: [productId], orderBy: 'sort_order, id');
  }

  Future<int> saveProduct({
    required String name,
    required String baseUnit,
    required String trackingMode,
    required List<Map<String, Object?>> units,
    String? code,
    String? category,
  }) async {
    if (name.trim().isEmpty || baseUnit.trim().isEmpty) {
      throw ArgumentError('Product name and base unit are required');
    }
    if (units.isEmpty || !units.any((u) => u['unit_name'] == baseUnit)) {
      throw ArgumentError('A base unit with factor 1 is required');
    }
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('products', {
        'name': name.trim(), 'code': code?.trim().isEmpty == true ? null : code?.trim(),
        'category': category, 'base_unit_name': baseUnit,
        'tracking_mode': trackingMode, 'created_at': now, 'updated_at': now,
      });
      for (var i = 0; i < units.length; i++) {
        final u = units[i];
        final factor = (u['factor_to_base'] as num).toDouble();
        if (factor <= 0) throw ArgumentError('Unit conversion must be positive');
        await txn.insert('product_units', {
          'product_id': id, 'unit_name': u['unit_name'],
          'factor_to_base': factor, 'sort_order': i, 'created_at': now,
        });
      }
      return id;
    });
  }

  Future<List<Map<String, Object?>>> listParties(String table) async {
    if (table != 'suppliers' && table != 'customers') {
      throw ArgumentError('Unsupported party table');
    }
    final db = await database;
    return db.query(table, where: 'is_active=1', orderBy: 'name COLLATE NOCASE');
  }

  Future<int> saveParty({required bool supplier, required String name, String? phone}) async {
    if (name.trim().isEmpty) throw ArgumentError('Name is required');
    final db = await database;
    return db.insert(supplier ? 'suppliers' : 'customers', {
      'name': name.trim(), 'phone': phone,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> createDocument({
    required String kind,
    required String partyType,
    required int partyId,
    required String partyName,
    required int createdBy,
    required List<Map<String, Object?>> lines,
  }) async {
    if (kind != 'receipt' && kind != 'issue') throw ArgumentError('Unsupported document kind');
    if (lines.isEmpty) throw ArgumentError('Document must contain at least one line');
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final docId = await txn.insert('documents', {
        'document_no': '${kind == 'receipt' ? 'RCV' : 'ISS'}-$stamp',
        'kind': kind, 'status': 'draft', 'party_type': partyType,
        'party_id': partyId, 'party_name_snapshot': partyName,
        'created_by': createdBy, 'created_at': now,
      });
      for (final line in lines) {
        final productId = line['product_id'] as int;
        final productRows = await txn.query('products', where: 'id=?', whereArgs: [productId], limit: 1);
        if (productRows.isEmpty) throw StateError('Product not found');
        final qty = (line['quantity'] as num).toDouble();
        final factor = (line['factor_to_base'] as num).toDouble();
        if (qty <= 0 || factor <= 0) throw ArgumentError('Quantity and unit factor must be positive');
        await txn.insert('document_lines', {
          'document_id': docId, 'product_id': productId,
          'product_name_snapshot': productRows.first['name'],
          'unit_name_snapshot': line['unit_name'],
          'entered_quantity': qty, 'factor_to_base_snapshot': factor,
          'base_quantity': qty * factor,
          'unit_price_minor': line['unit_price_minor'] ?? 0,
          'packaging_note': line['packaging_note'],
          'created_at': now,
        });
      }
      return docId;
    });
  }

  Future<void> submitDocument({required int documentId, required int userId}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('documents', where: 'id=?', whereArgs: [documentId], limit: 1);
      if (rows.isEmpty || rows.first['status'] != 'draft') {
        throw StateError('Only a draft document can be submitted');
      }
      final count = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM document_lines WHERE document_id=?', [documentId])) ?? 0;
      if (count == 0) throw StateError('Empty documents cannot be submitted');
      final now = DateTime.now().toIso8601String();
      await txn.update('documents', {'status':'pending_approval','submitted_at':now},
        where:'id=?', whereArgs:[documentId]);
      await txn.insert('approval_history', {
        'document_id':documentId, 'action':'submitted', 'actor_id':userId,
        'actor_name_snapshot':'User #$userId', 'created_at':now,
      });
    });
  }

  Future<List<Map<String, Object?>>> pendingDocuments() async {
    final db = await database;
    return db.query('documents', where:"status='pending_approval'",
      orderBy:'submitted_at ASC');
  }

  Future<void> rejectDocument({required int documentId, required int userId, required String reason}) async {
    if (reason.trim().isEmpty) throw ArgumentError('Rejection reason is required');
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('documents', where:'id=?', whereArgs:[documentId], limit:1);
      if (rows.isEmpty || rows.first['status'] != 'pending_approval') {
        throw StateError('Only pending documents can be rejected');
      }
      final now = DateTime.now().toIso8601String();
      await txn.update('documents', {'status':'rejected','rejection_reason':reason.trim()},
        where:'id=?', whereArgs:[documentId]);
      await txn.insert('approval_history', {
        'document_id':documentId, 'action':'rejected', 'actor_id':userId,
        'actor_name_snapshot':'User #$userId', 'notes':reason.trim(), 'created_at':now,
      });
    });
  }
}
