import 'package:sqflite/sqflite.dart';

/// Creates the Product Performance & Market Intelligence tables.
///
/// Operational transactions remain in the existing WMS tables. This schema
/// stores only market observations, competitor intelligence and decisions.
Future<void> createMarketAnalyticsSchema(DatabaseExecutor db) async {
  const statements = <String>[
    '''CREATE TABLE IF NOT EXISTS market_areas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      parent_area_id INTEGER REFERENCES market_areas(id) ON DELETE RESTRICT,
      area_code TEXT UNIQUE,
      name TEXT NOT NULL COLLATE NOCASE,
      area_type TEXT NOT NULL CHECK(area_type IN ('country','city','district','neighborhood','other')),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
      created_at TEXT NOT NULL,
      UNIQUE(parent_area_id, name)
    )''',
    '''CREATE TABLE IF NOT EXISTS market_segments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS market_data_sources (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source_type TEXT NOT NULL CHECK(source_type IN ('field_survey','customer_feedback','competitor_observation','supplier_quote','public_report','internal_estimate','other')),
      source_name TEXT NOT NULL,
      collection_method TEXT,
      reliability_score INTEGER CHECK(reliability_score BETWEEN 0 AND 100),
      notes TEXT,
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS product_market_profiles (
      product_id INTEGER PRIMARY KEY REFERENCES products(id) ON DELETE RESTRICT,
      brand TEXT,
      manufacturer TEXT,
      country_of_origin TEXT,
      customs_code TEXT,
      storage_requirements TEXT,
      updated_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS supplier_product_terms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      supplier_id INTEGER NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      lead_time_days INTEGER CHECK(lead_time_days >= 0),
      minimum_order_quantity_base REAL CHECK(minimum_order_quantity_base > 0),
      quoted_unit_cost_minor INTEGER CHECK(quoted_unit_cost_minor >= 0),
      currency_code TEXT,
      quote_valid_until TEXT,
      notes TEXT,
      updated_at TEXT NOT NULL,
      UNIQUE(supplier_id, product_id)
    )''',
    '''CREATE TABLE IF NOT EXISTS competitors (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL COLLATE NOCASE,
      competitor_type TEXT NOT NULL DEFAULT 'direct' CHECK(competitor_type IN ('direct','indirect','online','wholesale','retail','other')),
      phone TEXT,
      website TEXT,
      notes TEXT,
      is_confidential INTEGER NOT NULL DEFAULT 0 CHECK(is_confidential IN (0,1)),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS competitor_branches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      competitor_id INTEGER NOT NULL REFERENCES competitors(id) ON DELETE RESTRICT,
      area_id INTEGER REFERENCES market_areas(id) ON DELETE SET NULL,
      branch_name TEXT,
      address TEXT,
      latitude REAL,
      longitude REAL,
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS competitor_products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      competitor_id INTEGER NOT NULL REFERENCES competitors(id) ON DELETE RESTRICT,
      internal_product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      external_product_name TEXT NOT NULL,
      brand TEXT,
      manufacturer TEXT,
      country_of_origin TEXT,
      package_description TEXT,
      observed_unit_name TEXT,
      quantity_in_internal_base REAL CHECK(quantity_in_internal_base > 0),
      is_confidential INTEGER NOT NULL DEFAULT 0 CHECK(is_confidential IN (0,1)),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK(is_active IN (0,1)),
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS competitor_price_observations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      competitor_product_id INTEGER NOT NULL REFERENCES competitor_products(id) ON DELETE RESTRICT,
      branch_id INTEGER REFERENCES competitor_branches(id) ON DELETE SET NULL,
      data_source_id INTEGER REFERENCES market_data_sources(id) ON DELETE SET NULL,
      observed_price_minor INTEGER NOT NULL CHECK(observed_price_minor >= 0),
      currency_code TEXT NOT NULL,
      observed_quantity_in_internal_base REAL NOT NULL CHECK(observed_quantity_in_internal_base > 0),
      tax_included INTEGER NOT NULL DEFAULT 0 CHECK(tax_included IN (0,1)),
      observed_at TEXT NOT NULL,
      confidence_score INTEGER CHECK(confidence_score BETWEEN 0 AND 100),
      notes TEXT,
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS competitor_availability_observations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      competitor_product_id INTEGER NOT NULL REFERENCES competitor_products(id) ON DELETE RESTRICT,
      branch_id INTEGER REFERENCES competitor_branches(id) ON DELETE SET NULL,
      data_source_id INTEGER REFERENCES market_data_sources(id) ON DELETE SET NULL,
      availability_status TEXT NOT NULL CHECK(availability_status IN ('available','low_stock','out_of_stock','unknown')),
      observed_at TEXT NOT NULL,
      confidence_score INTEGER CHECK(confidence_score BETWEEN 0 AND 100),
      notes TEXT,
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS market_demand_observations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      product_name_snapshot TEXT NOT NULL,
      area_id INTEGER NOT NULL REFERENCES market_areas(id) ON DELETE RESTRICT,
      segment_id INTEGER REFERENCES market_segments(id) ON DELETE SET NULL,
      data_source_id INTEGER REFERENCES market_data_sources(id) ON DELETE SET NULL,
      observation_type TEXT NOT NULL CHECK(observation_type IN ('observed','surveyed','estimated')),
      period_start TEXT NOT NULL,
      period_end TEXT NOT NULL,
      demand_quantity_base REAL NOT NULL CHECK(demand_quantity_base >= 0),
      base_unit_name_snapshot TEXT NOT NULL,
      estimated_sales_value_minor INTEGER CHECK(estimated_sales_value_minor >= 0),
      currency_code TEXT,
      confidence_score INTEGER CHECK(confidence_score BETWEEN 0 AND 100),
      notes TEXT,
      created_at TEXT NOT NULL,
      CHECK(period_end >= period_start)
    )''',
    '''CREATE TABLE IF NOT EXISTS unfulfilled_demand (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      product_name_snapshot TEXT NOT NULL,
      area_id INTEGER REFERENCES market_areas(id) ON DELETE SET NULL,
      customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
      requested_quantity_base REAL NOT NULL CHECK(requested_quantity_base > 0),
      base_unit_name_snapshot TEXT NOT NULL,
      reason_code TEXT NOT NULL CHECK(reason_code IN ('out_of_stock','price','not_carried','delivery_limit','quality','other')),
      competitor_id INTEGER REFERENCES competitors(id) ON DELETE SET NULL,
      request_date TEXT NOT NULL,
      fulfilled_later INTEGER NOT NULL DEFAULT 0 CHECK(fulfilled_later IN (0,1)),
      notes TEXT,
      created_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS market_size_estimates (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
      area_id INTEGER NOT NULL REFERENCES market_areas(id) ON DELETE RESTRICT,
      data_source_id INTEGER REFERENCES market_data_sources(id) ON DELETE SET NULL,
      period_start TEXT NOT NULL,
      period_end TEXT NOT NULL,
      total_market_quantity_base REAL NOT NULL CHECK(total_market_quantity_base > 0),
      base_unit_name_snapshot TEXT NOT NULL,
      total_market_sales_value_minor INTEGER CHECK(total_market_sales_value_minor >= 0),
      currency_code TEXT,
      estimation_method TEXT NOT NULL,
      confidence_score INTEGER CHECK(confidence_score BETWEEN 0 AND 100),
      notes TEXT,
      created_at TEXT NOT NULL,
      CHECK(period_end >= period_start)
    )''',
    '''CREATE TABLE IF NOT EXISTS growth_opportunities (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
      area_id INTEGER REFERENCES market_areas(id) ON DELETE SET NULL,
      opportunity_type TEXT NOT NULL CHECK(opportunity_type IN ('new_product','increase_supply','price_positioning','new_area','new_segment','competitor_gap','other')),
      title TEXT NOT NULL,
      description TEXT,
      estimated_monthly_demand_base REAL CHECK(estimated_monthly_demand_base >= 0),
      estimated_gross_margin_minor INTEGER CHECK(estimated_gross_margin_minor >= 0),
      estimated_investment_minor INTEGER CHECK(estimated_investment_minor >= 0),
      priority TEXT NOT NULL DEFAULT 'medium' CHECK(priority IN ('low','medium','high','critical')),
      status TEXT NOT NULL DEFAULT 'identified' CHECK(status IN ('identified','under_review','approved','rejected','implemented','on_hold')),
      created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS market_decisions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      opportunity_id INTEGER NOT NULL REFERENCES growth_opportunities(id) ON DELETE RESTRICT,
      decision TEXT NOT NULL CHECK(decision IN ('approved','rejected','deferred','more_research')),
      planned_quantity_base REAL CHECK(planned_quantity_base > 0),
      budget_minor INTEGER CHECK(budget_minor >= 0),
      target_date TEXT,
      rationale TEXT NOT NULL,
      decided_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
      decided_at TEXT NOT NULL
    )''',
    'CREATE INDEX IF NOT EXISTS idx_market_areas_parent ON market_areas(parent_area_id)',
    'CREATE INDEX IF NOT EXISTS idx_competitor_branches_area ON competitor_branches(area_id, competitor_id)',
    'CREATE INDEX IF NOT EXISTS idx_competitor_products_internal ON competitor_products(internal_product_id)',
    'CREATE INDEX IF NOT EXISTS idx_competitor_prices_product_date ON competitor_price_observations(competitor_product_id, observed_at)',
    'CREATE INDEX IF NOT EXISTS idx_competitor_availability_product_date ON competitor_availability_observations(competitor_product_id, observed_at)',
    'CREATE INDEX IF NOT EXISTS idx_market_demand_product_area_period ON market_demand_observations(product_id, area_id, period_start, period_end)',
    'CREATE INDEX IF NOT EXISTS idx_unfulfilled_demand_product_date ON unfulfilled_demand(product_id, request_date)',
    'CREATE INDEX IF NOT EXISTS idx_market_size_product_area_period ON market_size_estimates(product_id, area_id, period_start, period_end)',
    'CREATE INDEX IF NOT EXISTS idx_growth_opportunities_status ON growth_opportunities(status, priority)',
  ];

  for (final statement in statements) {
    await db.execute(statement);
  }

  const permissions = <Map<String, String>>[
    {'permission_key': 'market.analytics.view', 'label_ar': 'عرض أداء المنتجات وتحليل السوق', 'module': 'تحليل السوق'},
    {'permission_key': 'market.demand.manage', 'label_ar': 'إدارة بيانات الطلب واحتياجات السوق', 'module': 'تحليل السوق'},
    {'permission_key': 'market.competitors.manage', 'label_ar': 'إدارة بيانات المنافسين', 'module': 'تحليل السوق'},
    {'permission_key': 'market.decisions.manage', 'label_ar': 'إدارة فرص النمو وقرارات الاستيراد', 'module': 'تحليل السوق'},
  ];
  for (final permission in permissions) {
    await db.insert(
      'permissions',
      permission,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
