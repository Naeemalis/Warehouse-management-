import '../domain/unit_conversion.dart';
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
      version: 3,
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''CREATE TABLE customer_payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
            amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
            payment_date TEXT NOT NULL,
            payment_method TEXT NOT NULL DEFAULT 'cash',
            reference_no TEXT, notes TEXT,
            created_by INTEGER, created_at TEXT NOT NULL
          )''');
          await db.execute('CREATE INDEX idx_customer_payments_customer_date ON customer_payments(customer_id, payment_date)');
        }
        if (oldVersion < 3) {
          await _createExpiryTraceabilitySchema(db);
          final incoming = await db.rawQuery("""
            SELECT m.id movement_id,m.document_id,m.product_id,m.quantity_base,m.created_at,
              l.id line_id,l.entered_quantity,l.unit_name_snapshot,l.factor_to_base_snapshot
            FROM stock_movements m JOIN document_lines l ON l.id=m.document_line_id
            WHERE m.direction='IN' ORDER BY m.created_at,m.id
          """);
          for (final r in incoming) {
            final batchId=await db.insert('stock_batches',{
              'product_id':r['product_id'],'receipt_document_id':r['document_id'],
              'receipt_document_line_id':r['line_id'],'expiry_date':null,
              'received_quantity_base':r['quantity_base'],'received_quantity':r['entered_quantity'],
              'unit_name_snapshot':r['unit_name_snapshot'],'factor_to_base_snapshot':r['factor_to_base_snapshot'],
              'created_at':r['created_at'],
            });
            await db.insert('stock_movement_allocations',{
              'stock_movement_id':r['movement_id'],'batch_id':batchId,
              'quantity_base':r['quantity_base'],'entered_quantity':r['entered_quantity'],
              'unit_name_snapshot':r['unit_name_snapshot'],'factor_to_base_snapshot':r['factor_to_base_snapshot'],
            });
          }
          final outgoing=await db.rawQuery("""
            SELECT m.id movement_id,m.product_id,m.quantity_base,m.created_at,
              l.unit_name_snapshot,l.factor_to_base_snapshot
            FROM stock_movements m JOIN document_lines l ON l.id=m.document_line_id
            WHERE m.direction='OUT' ORDER BY m.created_at,m.id
          """);
          for(final m in outgoing){
            var remaining=(m['quantity_base'] as num).toDouble();
            final batches=await db.rawQuery("""
              SELECT b.*,b.received_quantity_base-COALESCE((
                SELECT SUM(a.quantity_base) FROM stock_movement_allocations a
                JOIN stock_movements sm ON sm.id=a.stock_movement_id
                WHERE a.batch_id=b.id AND sm.direction='OUT'
              ),0) available_base
              FROM stock_batches b WHERE b.product_id=? ORDER BY b.created_at,b.id
            """,[m['product_id']]);
            for(final b in batches){
              if(remaining<=0.000001) break;
              final available=(b['available_base'] as num).toDouble();
              if(available<=0) continue;
              final take=available<remaining?available:remaining;
              final factor=(m['factor_to_base_snapshot'] as num).toDouble();
              await db.insert('stock_movement_allocations',{
                'stock_movement_id':m['movement_id'],'batch_id':b['id'],
                'quantity_base':take,'entered_quantity':take/factor,
                'unit_name_snapshot':m['unit_name_snapshot'],'factor_to_base_snapshot':factor,
              });
              remaining-=take;
            }
          }
        }
      },
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
    await db.execute('''CREATE TABLE customer_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
      amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
      payment_date TEXT NOT NULL,
      payment_method TEXT NOT NULL DEFAULT 'cash',
      reference_no TEXT, notes TEXT,
      created_by INTEGER, created_at TEXT NOT NULL
    )''');
    await db.execute('CREATE INDEX idx_customer_payments_customer_date ON customer_payments(customer_id, payment_date)');
    await db.execute('CREATE TABLE app_settings (setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)');
    await db.execute('CREATE INDEX idx_product_units_product ON product_units(product_id)');
    await db.execute('CREATE INDEX idx_documents_status ON documents(status, kind)');
    await db.execute('CREATE INDEX idx_document_lines_document ON document_lines(document_id)');
    await db.execute('CREATE INDEX idx_movements_product ON stock_movements(product_id, created_at)');
    await db.insert('app_settings', {'setting_key': 'language', 'setting_value': 'ar'});
    await _createExpiryTraceabilitySchema(db);
  }

  Future<void> _createExpiryTraceabilitySchema(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS document_line_expiry_splits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_line_id INTEGER NOT NULL REFERENCES document_lines(id) ON DELETE RESTRICT,
      expiry_date TEXT,
      entered_quantity REAL NOT NULL CHECK(entered_quantity > 0),
      unit_name_snapshot TEXT NOT NULL,
      factor_to_base_snapshot REAL NOT NULL CHECK(factor_to_base_snapshot > 0),
      quantity_base REAL NOT NULL CHECK(quantity_base > 0),
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS stock_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      receipt_document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
      receipt_document_line_id INTEGER NOT NULL REFERENCES document_lines(id) ON DELETE RESTRICT,
      expiry_date TEXT,
      received_quantity_base REAL NOT NULL CHECK(received_quantity_base > 0),
      received_quantity REAL NOT NULL CHECK(received_quantity > 0),
      unit_name_snapshot TEXT NOT NULL,
      factor_to_base_snapshot REAL NOT NULL CHECK(factor_to_base_snapshot > 0),
      created_at TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS stock_movement_allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      stock_movement_id INTEGER NOT NULL REFERENCES stock_movements(id) ON DELETE RESTRICT,
      batch_id INTEGER NOT NULL REFERENCES stock_batches(id) ON DELETE RESTRICT,
      quantity_base REAL NOT NULL CHECK(quantity_base > 0),
      entered_quantity REAL NOT NULL CHECK(entered_quantity > 0),
      unit_name_snapshot TEXT NOT NULL,
      factor_to_base_snapshot REAL NOT NULL CHECK(factor_to_base_snapshot > 0)
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expiry_splits_line ON document_line_expiry_splits(document_line_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_batches_product_expiry ON stock_batches(product_id,expiry_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_movement_allocations_batch ON stock_movement_allocations(batch_id)');
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
      for(final line in lines){
        final movementId=await txn.insert('stock_movements',{
          'document_id':documentId,'document_line_id':line['id'],
          'product_id':line['product_id'],'direction':kind=='receipt'?'IN':'OUT',
          'quantity_base':line['base_quantity'],'created_by':approverId,'created_at':now,
        });
        if(kind=='receipt'){
          final splits=await txn.query('document_line_expiry_splits',
            where:'document_line_id=?',whereArgs:[line['id']],orderBy:'id');
          if(splits.isEmpty){
            final batchId=await txn.insert('stock_batches',{
              'product_id':line['product_id'],'receipt_document_id':documentId,
              'receipt_document_line_id':line['id'],'expiry_date':null,
              'received_quantity_base':line['base_quantity'],'received_quantity':line['entered_quantity'],
              'unit_name_snapshot':line['unit_name_snapshot'],
              'factor_to_base_snapshot':line['factor_to_base_snapshot'],'created_at':now,
            });
            await txn.insert('stock_movement_allocations',{
              'stock_movement_id':movementId,'batch_id':batchId,
              'quantity_base':line['base_quantity'],'entered_quantity':line['entered_quantity'],
              'unit_name_snapshot':line['unit_name_snapshot'],
              'factor_to_base_snapshot':line['factor_to_base_snapshot'],
            });
          }else{
            for(final split in splits){
              final batchId=await txn.insert('stock_batches',{
                'product_id':line['product_id'],'receipt_document_id':documentId,
                'receipt_document_line_id':line['id'],'expiry_date':split['expiry_date'],
                'received_quantity_base':split['quantity_base'],'received_quantity':split['entered_quantity'],
                'unit_name_snapshot':split['unit_name_snapshot'],
                'factor_to_base_snapshot':split['factor_to_base_snapshot'],'created_at':now,
              });
              await txn.insert('stock_movement_allocations',{
                'stock_movement_id':movementId,'batch_id':batchId,
                'quantity_base':split['quantity_base'],'entered_quantity':split['entered_quantity'],
                'unit_name_snapshot':split['unit_name_snapshot'],
                'factor_to_base_snapshot':split['factor_to_base_snapshot'],
              });
            }
          }
        }else{
          var remaining=(line['base_quantity'] as num).toDouble();
          final today=DateTime.now().toIso8601String().substring(0,10);
          final batches=await txn.rawQuery("""
            SELECT b.*,b.received_quantity_base-COALESCE((
              SELECT SUM(a.quantity_base) FROM stock_movement_allocations a
              JOIN stock_movements sm ON sm.id=a.stock_movement_id
              WHERE a.batch_id=b.id AND sm.direction='OUT'
            ),0) available_base
            FROM stock_batches b
            WHERE b.product_id=? AND (b.expiry_date IS NULL OR b.expiry_date>=?)
            ORDER BY CASE WHEN b.expiry_date IS NULL THEN 1 ELSE 0 END,
              b.expiry_date ASC,b.created_at ASC,b.id ASC
          """,[line['product_id'],today]);
          for(final batch in batches){
            if(remaining<=0.000001) break;
            final available=(batch['available_base'] as num).toDouble();
            if(available<=0.000001) continue;
            final take=available<remaining?available:remaining;
            final factor=(line['factor_to_base_snapshot'] as num).toDouble();
            await txn.insert('stock_movement_allocations',{
              'stock_movement_id':movementId,'batch_id':batch['id'],
              'quantity_base':take,'entered_quantity':take/factor,
              'unit_name_snapshot':line['unit_name_snapshot'],
              'factor_to_base_snapshot':factor,
            });
            remaining-=take;
          }
          if(remaining>0.000001) throw StateError('Insufficient non-expired stock for ${line['product_name_snapshot']}');
        }
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
          FROM stock_movements m WHERE m.product_id=p.id),0) AS stock_base,
        (SELECT MIN(b.expiry_date) FROM stock_batches b
          WHERE b.product_id=p.id AND b.expiry_date IS NOT NULL
          AND b.received_quantity_base-COALESCE((
            SELECT SUM(a.quantity_base) FROM stock_movement_allocations a
            JOIN stock_movements om ON om.id=a.stock_movement_id
            WHERE a.batch_id=b.id AND om.direction='OUT'
          ),0)>0) AS nearest_expiry_date,
        COALESCE(
          (SELECT MAX(m.created_at) FROM stock_movements m WHERE m.product_id=p.id AND m.direction='OUT'),
          (SELECT MAX(m.created_at) FROM stock_movements m WHERE m.product_id=p.id AND m.direction='IN')
        ) AS last_activity_at
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
    validateUnitDefinitions(units, baseUnit);
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
        final unitName = (line['unit_name'] as String?)?.trim() ?? '';
        final unitRows = await txn.query('product_units',
          where:'product_id=? AND unit_name=? AND is_active=1',
          whereArgs:[productId,unitName],limit:1);
        if(unitRows.isEmpty) throw StateError('Unit is not defined for this product: $unitName');
        final factor = (unitRows.first['factor_to_base'] as num).toDouble();
        final qty = (line['quantity'] as num).toDouble();
        if (!qty.isFinite || qty <= 0 || !factor.isFinite || factor <= 0) {
          throw ArgumentError('Quantity and saved product unit must be valid');
        }
        final baseQty=convertToBaseQuantity(enteredQuantity:qty,factorToBase:factor);
        final lineId=await txn.insert('document_lines',{
          'document_id':docId,'product_id':productId,
          'product_name_snapshot':productRows.first['name'],
          'unit_name_snapshot':line['unit_name'],
          'entered_quantity':qty,'factor_to_base_snapshot':factor,'base_quantity':baseQty,
          'unit_price_minor':line['unit_price_minor']??0,
          'packaging_note':line['packaging_note'],'created_at':now,
        });
        if(kind=='receipt'){
          final supplied=line['expiry_splits'] as List<Map<String,Object?>>?;
          final splits=supplied==null||supplied.isEmpty
            ? <Map<String,Object?>>[{'expiry_date':null,'quantity':qty,'unit_name':line['unit_name'],'factor_to_base':factor}]
            : supplied;
          var sumBase=0.0;
          for(final split in splits){
            final splitQty=(split['quantity'] as num).toDouble();
            final splitFactor=factor;
            final splitUnit=unitName;
            final expiry=split['expiry_date'] as String?;
            if(!splitQty.isFinite||splitQty<=0) throw ArgumentError('Expiry split quantity must be positive');
            if(expiry!=null&&DateTime.tryParse(expiry)==null) throw ArgumentError('Expiry date must use YYYY-MM-DD');
            final splitBase=convertToBaseQuantity(enteredQuantity:splitQty,factorToBase:splitFactor);
            sumBase+=splitBase;
            await txn.insert('document_line_expiry_splits',{
              'document_line_id':lineId,'expiry_date':expiry,'entered_quantity':splitQty,
              'unit_name_snapshot':splitUnit,'factor_to_base_snapshot':splitFactor,
              'quantity_base':splitBase,'created_at':now,
            });
          }
          if((sumBase-baseQty).abs()>0.000001) throw ArgumentError('Expiry split quantities must equal the received line quantity');
        }
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


extension WmsStockTraceability on WmsDatabase {
  Future<List<Map<String,Object?>>> productBatchBalances(int productId) async {
    final db=await database;
    return db.rawQuery("""
      SELECT b.*,b.received_quantity_base-COALESCE((
        SELECT SUM(a.quantity_base) FROM stock_movement_allocations a
        JOIN stock_movements m ON m.id=a.stock_movement_id
        WHERE a.batch_id=b.id AND m.direction='OUT'
      ),0) remaining_quantity_base
      FROM stock_batches b WHERE b.product_id=?
      ORDER BY CASE WHEN b.expiry_date IS NULL THEN 1 ELSE 0 END,
        b.expiry_date ASC,b.created_at ASC,b.id ASC
    """,[productId]);
  }

  Future<List<Map<String,Object?>>> productMovementHistory(int productId) async {
    final db=await database;
    return db.rawQuery("""
      SELECT m.id movement_id,m.direction,m.quantity_base,m.created_at,d.document_no,d.kind,
        l.entered_quantity,l.unit_name_snapshot,l.factor_to_base_snapshot,l.product_name_snapshot,
        a.entered_quantity allocated_quantity,a.unit_name_snapshot allocated_unit,
        a.quantity_base allocated_base_quantity,b.expiry_date,b.id batch_id
      FROM stock_movements m JOIN documents d ON d.id=m.document_id
      JOIN document_lines l ON l.id=m.document_line_id
      LEFT JOIN stock_movement_allocations a ON a.stock_movement_id=m.id
      LEFT JOIN stock_batches b ON b.id=a.batch_id
      WHERE m.product_id=? ORDER BY m.created_at,m.id,a.id
    """,[productId]);
  }
}

extension WmsDeliveryOperations on WmsDatabase {
  Future<List<Map<String, Object?>>> awaitingDeliveryDocuments() async {
    final db = await database;
    return db.query('documents',
      where: "kind='issue' AND status='approved' AND delivery_status='awaiting_delivery'",
      orderBy: 'approved_at ASC');
  }
}

extension WmsProductMaintenance on WmsDatabase {
  Future<void> updateProduct({
    required int productId,
    required String name,
    required int purchasePriceMinor,
    required int issuePriceMinor,
  }) async {
    if (name.trim().isEmpty) throw ArgumentError('Product name is required');
    final db = await database;
    await db.transaction((txn) async {
      final before = await txn.query('products', where:'id=?', whereArgs:[productId], limit:1);
      if (before.isEmpty) throw StateError('Product not found');
      final now = DateTime.now().toIso8601String();
      await txn.update('products', {
        'name':name.trim(),
        'purchase_price_minor':purchasePriceMinor,
        'issue_price_minor':issuePriceMinor,
        'updated_at':now,
      }, where:'id=?', whereArgs:[productId]);
      await txn.insert('audit_log', {
        'entity_type':'product','entity_id':productId,'action':'updated',
        'actor_id':1,
        'details':'Product name or prices changed',
        'created_at':now,
      });
    });
  }
}


extension WmsFinanceAndHistory on WmsDatabase {
  Future<List<Map<String, Object?>>> listDocuments({String? kind, int? partyId}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (kind != null) { clauses.add('d.kind=?'); args.add(kind); }
    if (partyId != null) { clauses.add('d.party_id=?'); args.add(partyId); }
    return db.rawQuery('''
      SELECT d.*,
        COALESCE((SELECT SUM(l.entered_quantity*l.unit_price_minor)
          FROM document_lines l WHERE l.document_id=d.id),0) AS total_minor,
        (SELECT COUNT(*) FROM document_lines l WHERE l.document_id=d.id) AS line_count
      FROM documents d
      ${clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}'}
      ORDER BY d.created_at DESC
    ''', args);
  }

  Future<Map<String, Object?>> documentDetails(int documentId) async {
    final db = await database;
    final docs = await db.rawQuery('''
      SELECT d.*, COALESCE((SELECT SUM(l.entered_quantity*l.unit_price_minor)
      FROM document_lines l WHERE l.document_id=d.id),0) AS total_minor
      FROM documents d WHERE d.id=?
    ''', [documentId]);
    if (docs.isEmpty) throw StateError('Document not found');
    final lines = await db.query('document_lines', where:'document_id=?',
      whereArgs:[documentId], orderBy:'id');
    return {'document':docs.first, 'lines':lines};
  }

  Future<void> addCustomerPayment({
    required int customerId, required int amountMinor,
    required String paymentDate, String method='cash',
    String? referenceNo, String? notes, int userId=1,
  }) async {
    if (amountMinor <= 0) throw ArgumentError('Payment must be positive');
    final db = await database;
    await db.transaction((txn) async {
      final customer = await txn.query('customers', where:'id=?', whereArgs:[customerId], limit:1);
      if (customer.isEmpty) throw StateError('Customer not found');
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('customer_payments', {
        'customer_id':customerId, 'amount_minor':amountMinor,
        'payment_date':paymentDate, 'payment_method':method,
        'reference_no':referenceNo, 'notes':notes,
        'created_by':userId, 'created_at':now,
      });
      await txn.insert('audit_log', {
        'entity_type':'customer_payment','entity_id':id,'action':'created',
        'actor_id':userId,'details':'Customer payment recorded',
        'created_at':now,
      });
    });
  }

  Future<Map<String, Object?>> customerStatement(int customerId) async {
    final db = await database;
    final customerRows = await db.query('customers', where:'id=?', whereArgs:[customerId], limit:1);
    if (customerRows.isEmpty) throw StateError('Customer not found');
    final docs = await db.rawQuery('''
      SELECT d.id,d.document_no,d.created_at AS entry_date,d.status,
        d.party_name_snapshot,
        COALESCE(SUM(l.entered_quantity*l.unit_price_minor),0) AS debit_minor,
        0 AS credit_minor, 'issue' AS entry_type
      FROM documents d JOIN document_lines l ON l.document_id=d.id
      WHERE d.kind='issue' AND d.status='approved' AND d.party_type='customer' AND d.party_id=?
      GROUP BY d.id
    ''', [customerId]);
    final payments = await db.rawQuery('''
      SELECT id, 'PAY-'||id AS document_no, payment_date AS entry_date,
        'recorded' AS status, '' AS party_name_snapshot,
        0 AS debit_minor, amount_minor AS credit_minor,
        'payment' AS entry_type, payment_method, reference_no, notes
      FROM customer_payments WHERE customer_id=?
    ''', [customerId]);
    final entries = [...docs, ...payments]
      ..sort((a,b) => '${a['entry_date']}'.compareTo('${b['entry_date']}'));
    var balance = 0;
    final ledger = <Map<String,Object?>>[];
    for (final entry in entries) {
      balance += (entry['debit_minor'] as num).round();
      balance -= (entry['credit_minor'] as num).round();
      ledger.add({...entry, 'balance_minor':balance});
    }
    return {
      'customer':customerRows.first,
      'entries':ledger,
      'total_debit_minor':docs.fold<int>(0,(s,e)=>s+(e['debit_minor'] as num).round()),
      'total_paid_minor':payments.fold<int>(0,(s,e)=>s+(e['credit_minor'] as num).round()),
      'balance_minor':balance,
    };
  }

  Future<void> updateParty({
    required String table, required int id, required String name, String? phone,
  }) async {
    if (table!='customers' && table!='suppliers') throw ArgumentError('Unsupported party table');
    if (name.trim().isEmpty) throw ArgumentError('Name is required');
    final db=await database;
    await db.transaction((txn) async {
      final rows=await txn.query(table,where:'id=?',whereArgs:[id],limit:1);
      if(rows.isEmpty) throw StateError('Record not found');
      await txn.update(table,{'name':name.trim(),'phone':phone?.trim()},
        where:'id=?',whereArgs:[id]);
      await txn.insert('audit_log',{
        'entity_type':table.substring(0,table.length-1),'entity_id':id,
        'action':'updated','actor_id':1,'details':'Name or phone updated',
        'created_at':DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> archiveParty({required String table, required int id}) async {
    if (table!='customers' && table!='suppliers') throw ArgumentError('Unsupported party table');
    final db=await database;
    await db.update(table,{'is_active':0},where:'id=?',whereArgs:[id]);
  }

  Future<void> archiveProduct(int productId) async {
    final db=await database;
    await db.transaction((txn) async {
      final rows=await txn.query('products',where:'id=?',whereArgs:[productId],limit:1);
      if(rows.isEmpty) throw StateError('Product not found');
      await txn.update('products',{'is_active':0,'updated_at':DateTime.now().toIso8601String()},
        where:'id=?',whereArgs:[productId]);
      await txn.insert('audit_log',{
        'entity_type':'product','entity_id':productId,'action':'archived',
        'actor_id':1,'details':'Product hidden from active catalogue; history preserved',
        'created_at':DateTime.now().toIso8601String(),
      });
    });
  }
}
