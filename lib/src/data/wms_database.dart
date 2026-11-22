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
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
    );
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
    final statements = <String>[
      """CREATE TABLE units (
        id INTEGER PRIMARY KEY, code TEXT NOT NULL UNIQUE, name_ar TEXT NOT NULL,
        symbol TEXT, allows_fraction INTEGER NOT NULL DEFAULT 0 CHECK(allows_fraction IN (0,1))
      )""",
      """CREATE TABLE categories (
        id INTEGER PRIMARY KEY, name_ar TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
      )""",
      """CREATE TABLE products (
        id INTEGER PRIMARY KEY, sku TEXT UNIQUE, name_ar TEXT NOT NULL,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        base_unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
        min_stock REAL NOT NULL DEFAULT 0 CHECK(min_stock >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )""",
      """CREATE TABLE product_units (
        id INTEGER PRIMARY KEY, product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
        unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
        factor_to_base REAL NOT NULL CHECK(factor_to_base > 0),
        is_base_unit INTEGER NOT NULL DEFAULT 0 CHECK(is_base_unit IN (0,1)),
        UNIQUE(product_id, unit_id)
      )""",
      "CREATE UNIQUE INDEX ux_product_one_base_unit ON product_units(product_id) WHERE is_base_unit=1",
      """CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, phone TEXT, address TEXT,
        opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
      )""",
      """CREATE TABLE recipients (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL, phone TEXT, department TEXT,
        opening_balance_minor INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1))
      )""",
      """CREATE TABLE receiving_documents (
        id INTEGER PRIMARY KEY, document_no TEXT NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
        document_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','pending_approval','approved','rejected','cancelled')),
        notes TEXT, total_minor INTEGER NOT NULL DEFAULT 0 CHECK(total_minor>=0),
        created_by INTEGER, approved_by INTEGER, approved_at TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )""",
      """CREATE TABLE receiving_lines (
        id INTEGER PRIMARY KEY, receiving_id INTEGER NOT NULL REFERENCES receiving_documents(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        entered_unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
        entered_quantity REAL NOT NULL CHECK(entered_quantity>0),
        factor_to_base REAL NOT NULL CHECK(factor_to_base>0),
        received_base_quantity REAL NOT NULL CHECK(received_base_quantity>0),
        unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor>=0),
        line_total_minor INTEGER NOT NULL CHECK(line_total_minor>=0), line_note TEXT
      )""",
      """CREATE TABLE issue_documents (
        id INTEGER PRIMARY KEY, document_no TEXT NOT NULL UNIQUE,
        recipient_id INTEGER REFERENCES recipients(id) ON DELETE RESTRICT,
        document_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','pending_approval','approved','rejected','cancelled')),
        notes TEXT, created_by INTEGER, approved_by INTEGER, approved_at TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )""",
      """CREATE TABLE issue_lines (
        id INTEGER PRIMARY KEY, issue_id INTEGER NOT NULL REFERENCES issue_documents(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        entered_unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
        entered_quantity REAL NOT NULL CHECK(entered_quantity>0),
        factor_to_base REAL NOT NULL CHECK(factor_to_base>0),
        issue_base_quantity REAL NOT NULL CHECK(issue_base_quantity>0), line_note TEXT
      )""",
      """CREATE TABLE stock_batches (
        id INTEGER PRIMARY KEY, receiving_line_id INTEGER NOT NULL UNIQUE REFERENCES receiving_lines(id) ON DELETE RESTRICT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        received_base_quantity REAL NOT NULL CHECK(received_base_quantity>0),
        remaining_base_quantity REAL NOT NULL CHECK(remaining_base_quantity>=0),
        unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor>=0), received_at TEXT NOT NULL
      )""",
      """CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY, product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        batch_id INTEGER REFERENCES stock_batches(id) ON DELETE RESTRICT,
        movement_type TEXT NOT NULL CHECK(movement_type IN ('RECEIPT','ISSUE','SUPPLIER_RETURN','COUNT_GAIN','COUNT_LOSS','ADJUSTMENT')),
        direction TEXT NOT NULL CHECK(direction IN ('IN','OUT')),
        quantity_base REAL NOT NULL CHECK(quantity_base>0),
        source_type TEXT NOT NULL, source_id INTEGER NOT NULL, source_line_id INTEGER,
        occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, created_by INTEGER, note TEXT
      )""",
      """CREATE TABLE supplier_returns (
        id INTEGER PRIMARY KEY, document_no TEXT NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
        return_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','pending_approval','approved','rejected','cancelled')),
        notes TEXT, created_by INTEGER, approved_by INTEGER, approved_at TEXT
      )""",
      """CREATE TABLE supplier_return_lines (
        id INTEGER PRIMARY KEY, return_id INTEGER NOT NULL REFERENCES supplier_returns(id) ON DELETE CASCADE,
        receiving_line_id INTEGER NOT NULL REFERENCES receiving_lines(id) ON DELETE RESTRICT,
        batch_id INTEGER NOT NULL REFERENCES stock_batches(id) ON DELETE RESTRICT,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        return_base_quantity REAL NOT NULL CHECK(return_base_quantity>0),
        unit_cost_minor INTEGER NOT NULL CHECK(unit_cost_minor>=0)
      )""",
      """CREATE TABLE inventory_counts (
        id INTEGER PRIMARY KEY, document_no TEXT NOT NULL UNIQUE, count_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','active','pending_approval','approved','cancelled')),
        notes TEXT, created_by INTEGER, approved_by INTEGER, approved_at TEXT, started_at TEXT, closed_at TEXT
      )""",
      """CREATE TABLE inventory_count_lines (
        id INTEGER PRIMARY KEY, count_id INTEGER NOT NULL REFERENCES inventory_counts(id) ON DELETE CASCADE,
        product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
        system_quantity_base REAL NOT NULL CHECK(system_quantity_base>=0),
        counted_quantity_base REAL CHECK(counted_quantity_base>=0), difference_base REAL,
        UNIQUE(count_id, product_id)
      )""",
      """CREATE TABLE audit_log (
        id INTEGER PRIMARY KEY, user_id INTEGER, action TEXT NOT NULL,
        entity_type TEXT NOT NULL, entity_id INTEGER NOT NULL, details TEXT,
        occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )""",
      "CREATE INDEX ix_batches_product ON stock_batches(product_id)",
      "CREATE INDEX ix_movements_product_date ON stock_movements(product_id, occurred_at)",
      "CREATE INDEX ix_count_status ON inventory_counts(status)",
      """CREATE TRIGGER trg_freeze_stock_during_count
        BEFORE INSERT ON stock_movements
        WHEN EXISTS(SELECT 1 FROM inventory_counts WHERE status='active')
        BEGIN SELECT RAISE(ABORT, 'Inventory is frozen while a count is active'); END""",
      "INSERT OR IGNORE INTO units(id,code,name_ar,symbol,allows_fraction) VALUES (1,'piece','قطعة','قطعة',0),(2,'kg','كيلوغرام','كجم',1),(3,'g','جرام','جم',1)",
    ];
    for (final sql in statements) {
      await db.execute(sql);
    }
  }
}
