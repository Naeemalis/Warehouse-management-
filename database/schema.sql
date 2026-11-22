PRAGMA foreign_keys = ON;

-- NaeemSoft WMS: local, single-warehouse SQLite foundation.
-- Quantities are stored in the product's base unit. Use REAL only where
-- fractional quantities are legitimate (e.g. kg/g); money uses integer minor units.

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS roles (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name_ar TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS permissions (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name_ar TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS role_permissions (
  role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id INTEGER NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  username TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_roles (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE RESTRICT,
  PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS units (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name_ar TEXT NOT NULL,
  symbol TEXT,
  allows_fraction INTEGER NOT NULL DEFAULT 0 CHECK (allows_fraction IN (0,1))
);

CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY,
  name_ar TEXT NOT NULL UNIQUE,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
);

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY,
  sku TEXT UNIQUE,
  name_ar TEXT NOT NULL,
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  base_unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  min_stock REAL NOT NULL DEFAULT 0 CHECK (min_stock >= 0),
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Each factor means: 1 of this unit = factor base units.
-- Pricing is deliberately not derived from conversion factors.
CREATE TABLE IF NOT EXISTS product_units (
  id INTEGER PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  factor_to_base REAL NOT NULL CHECK (factor_to_base > 0),
  is_base_unit INTEGER NOT NULL DEFAULT 0 CHECK (is_base_unit IN (0,1)),
  UNIQUE(product_id, unit_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_product_one_base_unit
  ON product_units(product_id) WHERE is_base_unit = 1;

CREATE TABLE IF NOT EXISTS suppliers (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  address TEXT,
  opening_balance_minor INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
);

CREATE TABLE IF NOT EXISTS recipients (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  department TEXT,
  opening_balance_minor INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1))
);

CREATE TABLE IF NOT EXISTS receiving_documents (
  id INTEGER PRIMARY KEY,
  document_no TEXT NOT NULL UNIQUE,
  supplier_id INTEGER NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
  document_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','pending_approval','approved','rejected','cancelled')),
  notes TEXT,
  total_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_minor >= 0),
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS receiving_lines (
  id INTEGER PRIMARY KEY,
  receiving_id INTEGER NOT NULL REFERENCES receiving_documents(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  entered_unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  entered_quantity REAL NOT NULL CHECK (entered_quantity > 0),
  factor_to_base REAL NOT NULL CHECK (factor_to_base > 0),
  received_base_quantity REAL NOT NULL CHECK (received_base_quantity > 0),
  unit_cost_minor INTEGER NOT NULL CHECK (unit_cost_minor >= 0),
  line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
  line_note TEXT
);

CREATE TABLE IF NOT EXISTS issue_documents (
  id INTEGER PRIMARY KEY,
  document_no TEXT NOT NULL UNIQUE,
  recipient_id INTEGER REFERENCES recipients(id) ON DELETE RESTRICT,
  document_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','pending_approval','approved','rejected','cancelled')),
  notes TEXT,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS issue_lines (
  id INTEGER PRIMARY KEY,
  issue_id INTEGER NOT NULL REFERENCES issue_documents(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  entered_unit_id INTEGER NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  entered_quantity REAL NOT NULL CHECK (entered_quantity > 0),
  factor_to_base REAL NOT NULL CHECK (factor_to_base > 0),
  issue_base_quantity REAL NOT NULL CHECK (issue_base_quantity > 0),
  line_note TEXT
);

-- A batch is created only when its receiving document is approved.
CREATE TABLE IF NOT EXISTS stock_batches (
  id INTEGER PRIMARY KEY,
  receiving_line_id INTEGER UNIQUE REFERENCES receiving_lines(id) ON DELETE RESTRICT,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  received_base_quantity REAL NOT NULL CHECK (received_base_quantity > 0),
  remaining_base_quantity REAL NOT NULL CHECK (remaining_base_quantity >= 0),
  unit_cost_minor INTEGER NOT NULL CHECK (unit_cost_minor >= 0),
  received_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS stock_movements (
  id INTEGER PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  batch_id INTEGER REFERENCES stock_batches(id) ON DELETE RESTRICT,
  movement_type TEXT NOT NULL CHECK (movement_type IN
    ('RECEIPT','ISSUE','SUPPLIER_RETURN','COUNT_GAIN','COUNT_LOSS','ADJUSTMENT')),
  direction TEXT NOT NULL CHECK (direction IN ('IN','OUT')),
  quantity_base REAL NOT NULL CHECK (quantity_base > 0),
  source_type TEXT NOT NULL,
  source_id INTEGER NOT NULL,
  source_line_id INTEGER,
  occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  note TEXT
);

CREATE TABLE IF NOT EXISTS supplier_returns (
  id INTEGER PRIMARY KEY,
  document_no TEXT NOT NULL UNIQUE,
  supplier_id INTEGER NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
  return_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','pending_approval','approved','rejected','cancelled')),
  notes TEXT,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_at TEXT
);

-- Return lines must point to the original receipt line and its resulting batch.
CREATE TABLE IF NOT EXISTS supplier_return_lines (
  id INTEGER PRIMARY KEY,
  return_id INTEGER NOT NULL REFERENCES supplier_returns(id) ON DELETE CASCADE,
  receiving_line_id INTEGER NOT NULL REFERENCES receiving_lines(id) ON DELETE RESTRICT,
  batch_id INTEGER NOT NULL REFERENCES stock_batches(id) ON DELETE RESTRICT,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  return_base_quantity REAL NOT NULL CHECK (return_base_quantity > 0),
  unit_cost_minor INTEGER NOT NULL CHECK (unit_cost_minor >= 0)
);

CREATE TABLE IF NOT EXISTS inventory_counts (
  id INTEGER PRIMARY KEY,
  document_no TEXT NOT NULL UNIQUE,
  count_date TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','active','pending_approval','approved','cancelled')),
  notes TEXT,
  created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
  approved_at TEXT,
  started_at TEXT,
  closed_at TEXT
);

CREATE TABLE IF NOT EXISTS inventory_count_lines (
  id INTEGER PRIMARY KEY,
  count_id INTEGER NOT NULL REFERENCES inventory_counts(id) ON DELETE CASCADE,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  system_quantity_base REAL NOT NULL CHECK (system_quantity_base >= 0),
  counted_quantity_base REAL CHECK (counted_quantity_base >= 0),
  difference_base REAL,
  UNIQUE(count_id, product_id)
);

CREATE TABLE IF NOT EXISTS audit_log (
  id INTEGER PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id INTEGER NOT NULL,
  details TEXT,
  occurred_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_products_name ON products(name_ar);
CREATE INDEX IF NOT EXISTS ix_receiving_supplier_date ON receiving_documents(supplier_id, document_date);
CREATE INDEX IF NOT EXISTS ix_issue_recipient_date ON issue_documents(recipient_id, document_date);
CREATE INDEX IF NOT EXISTS ix_batches_product ON stock_batches(product_id);
CREATE INDEX IF NOT EXISTS ix_movements_product_date ON stock_movements(product_id, occurred_at);
CREATE INDEX IF NOT EXISTS ix_movements_source ON stock_movements(source_type, source_id);
CREATE INDEX IF NOT EXISTS ix_count_status ON inventory_counts(status);

-- Prevent ledger writes while an inventory count is active.
CREATE TRIGGER IF NOT EXISTS trg_block_movements_during_active_count
BEFORE INSERT ON stock_movements
WHEN EXISTS (SELECT 1 FROM inventory_counts WHERE status = 'active') AND NEW.source_type <> 'inventory_count'
BEGIN
  SELECT RAISE(ABORT, 'Inventory is frozen while a count is active');
END;

-- Approved receiving documents are immutable; corrections use reversal documents.
CREATE TRIGGER IF NOT EXISTS trg_no_receiving_line_edit_after_approval
BEFORE UPDATE ON receiving_lines
WHEN (SELECT status FROM receiving_documents WHERE id = OLD.receiving_id) = 'approved'
BEGIN
  SELECT RAISE(ABORT, 'Approved receiving lines are immutable');
END;

CREATE TRIGGER IF NOT EXISTS trg_no_receiving_line_delete_after_approval
BEFORE DELETE ON receiving_lines
WHEN (SELECT status FROM receiving_documents WHERE id = OLD.receiving_id) = 'approved'
BEGIN
  SELECT RAISE(ABORT, 'Approved receiving lines cannot be deleted');
END;

INSERT OR IGNORE INTO app_settings(key, value) VALUES
  ('schema_version', '1'),
  ('warehouse_mode', 'single_local'),
  ('stock_posting_rule', 'approved_documents_only');
