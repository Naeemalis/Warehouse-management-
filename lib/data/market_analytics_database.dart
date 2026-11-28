import 'access_control.dart';
import 'wms_database.dart';

/// Read/write operations for market intelligence.
///
/// These methods intentionally read realized sales/issues/receipts from the
/// existing approved WMS ledger. Market observations are stored separately.
extension WmsMarketAnalytics on WmsDatabase {
  Future<void> _requireMarketPermission(int userId, String permissionKey) async {
    if (!await userHasPermission(userId, permissionKey)) {
      throw StateError('Permission denied: $permissionKey');
    }
  }

  String _marketDate(String value, String field) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null || value.length < 10) {
      throw ArgumentError('$field must be a valid ISO date');
    }
    return value.substring(0, 10);
  }

  Future<List<Map<String, Object?>>> productMarketPerformance({
    required int userId,
    required String periodStart,
    required String periodEnd,
  }) async {
    final start = _marketDate(periodStart, 'periodStart');
    final end = _marketDate(periodEnd, 'periodEnd');
    if (end.compareTo(start) < 0) throw ArgumentError('periodEnd precedes periodStart');
    await _requireMarketPermission(userId, 'market.analytics.view');
    final db = await database;
    return db.rawQuery("""
      WITH
      receipts AS (
        SELECT l.product_id, SUM(l.base_quantity) AS received_base
        FROM documents d JOIN document_lines l ON l.document_id=d.id
        WHERE d.kind='receipt' AND d.status='approved'
          AND substr(COALESCE(d.approved_at,d.created_at),1,10) BETWEEN ? AND ?
        GROUP BY l.product_id
      ),
      supplier_returns AS (
        SELECT l.product_id, SUM(l.base_quantity) AS returned_base
        FROM documents d JOIN document_lines l ON l.document_id=d.id
        WHERE d.kind='return_out' AND d.status='approved'
          AND substr(COALESCE(d.approved_at,d.created_at),1,10) BETWEEN ? AND ?
        GROUP BY l.product_id
      ),
      sales AS (
        SELECT l.product_id, SUM(l.base_quantity) AS sold_base,
          SUM(l.entered_quantity*l.unit_price_minor) AS sales_minor
        FROM documents d JOIN document_lines l ON l.document_id=d.id
        WHERE d.kind='issue' AND d.document_type='sale' AND d.status='approved'
          AND substr(COALESCE(d.approved_at,d.created_at),1,10) BETWEEN ? AND ?
        GROUP BY l.product_id
      ),
      sales_returns AS (
        SELECT original.product_id, SUM(return_line.base_quantity) AS returned_base,
          SUM(return_line.entered_quantity*return_line.unit_price_minor) AS returned_minor
        FROM documents rd
        JOIN document_lines return_line ON return_line.document_id=rd.id
        JOIN document_lines original ON original.id=return_line.reference_document_line_id
        JOIN documents original_doc ON original_doc.id=original.document_id
        WHERE rd.kind='return_in' AND rd.status='approved'
          AND original_doc.kind='issue' AND original_doc.document_type='sale'
          AND substr(COALESCE(rd.approved_at,rd.created_at),1,10) BETWEEN ? AND ?
        GROUP BY original.product_id
      ),
      standard_issues AS (
        SELECT l.product_id, SUM(l.base_quantity) AS issued_base
        FROM documents d JOIN document_lines l ON l.document_id=d.id
        WHERE d.kind='issue' AND d.document_type='standard' AND d.status='approved'
          AND substr(COALESCE(d.approved_at,d.created_at),1,10) BETWEEN ? AND ?
        GROUP BY l.product_id
      ),
      standard_issue_returns AS (
        SELECT original.product_id, SUM(return_line.base_quantity) AS returned_base
        FROM documents rd
        JOIN document_lines return_line ON return_line.document_id=rd.id
        JOIN document_lines original ON original.id=return_line.reference_document_line_id
        JOIN documents original_doc ON original_doc.id=original.document_id
        WHERE rd.kind='return_in' AND rd.status='approved'
          AND original_doc.kind='issue' AND original_doc.document_type='standard'
          AND substr(COALESCE(rd.approved_at,rd.created_at),1,10) BETWEEN ? AND ?
        GROUP BY original.product_id
      ),
      current_stock AS (
        SELECT product_id,
          SUM(CASE WHEN direction='IN' THEN quantity_base ELSE -quantity_base END) AS stock_base
        FROM stock_movements GROUP BY product_id
      ),
      sales_cogs AS (
        SELECT m.product_id,
          SUM(a.quantity_base * receipt_line.unit_price_minor /
            NULLIF(receipt_line.factor_to_base_snapshot,0)) AS cogs_minor
        FROM stock_movements m
        JOIN documents sale_doc ON sale_doc.id=m.document_id
        JOIN stock_movement_allocations a ON a.stock_movement_id=m.id
        JOIN stock_batches b ON b.id=a.batch_id
        JOIN document_lines receipt_line ON receipt_line.id=b.receipt_document_line_id
        WHERE sale_doc.kind='issue' AND sale_doc.document_type='sale'
          AND sale_doc.status='approved' AND m.direction='OUT'
          AND substr(COALESCE(sale_doc.approved_at,sale_doc.created_at),1,10) BETWEEN ? AND ?
        GROUP BY m.product_id
      ),
      sales_return_cogs AS (
        SELECT m.product_id,
          SUM(a.quantity_base * receipt_line.unit_price_minor /
            NULLIF(receipt_line.factor_to_base_snapshot,0)) AS returned_cogs_minor
        FROM stock_movements m
        JOIN documents return_doc ON return_doc.id=m.document_id
        JOIN document_lines return_line ON return_line.id=m.document_line_id
        JOIN document_lines original_line ON original_line.id=return_line.reference_document_line_id
        JOIN documents original_doc ON original_doc.id=original_line.document_id
        JOIN stock_movement_allocations a ON a.stock_movement_id=m.id
        JOIN stock_batches b ON b.id=a.batch_id
        JOIN document_lines receipt_line ON receipt_line.id=b.receipt_document_line_id
        WHERE return_doc.kind='return_in' AND return_doc.status='approved'
          AND original_doc.kind='issue' AND original_doc.document_type='sale'
          AND m.direction='IN'
          AND substr(COALESCE(return_doc.approved_at,return_doc.created_at),1,10) BETWEEN ? AND ?
        GROUP BY m.product_id
      )
      SELECT p.id AS product_id,p.name,p.code,p.base_unit_name,
        COALESCE(r.received_base,0)-COALESCE(sr.returned_base,0) AS net_received_base,
        COALESCE(s.sold_base,0)-COALESCE(sret.returned_base,0) AS net_sold_base,
        COALESCE(s.sales_minor,0)-COALESCE(sret.returned_minor,0) AS net_sales_minor,
        COALESCE(i.issued_base,0)-COALESCE(iret.returned_base,0) AS net_issued_base,
        COALESCE(cs.stock_base,0) AS current_stock_base,
        COALESCE(s.sales_minor,0)-COALESCE(sret.returned_minor,0)
          -COALESCE(sc.cogs_minor,0)+COALESCE(src.returned_cogs_minor,0) AS gross_profit_minor
      FROM products p
      LEFT JOIN receipts r ON r.product_id=p.id
      LEFT JOIN supplier_returns sr ON sr.product_id=p.id
      LEFT JOIN sales s ON s.product_id=p.id
      LEFT JOIN sales_returns sret ON sret.product_id=p.id
      LEFT JOIN standard_issues i ON i.product_id=p.id
      LEFT JOIN standard_issue_returns iret ON iret.product_id=p.id
      LEFT JOIN current_stock cs ON cs.product_id=p.id
      LEFT JOIN sales_cogs sc ON sc.product_id=p.id
      LEFT JOIN sales_return_cogs src ON src.product_id=p.id
      WHERE p.is_active=1
      ORDER BY net_sales_minor DESC,p.name COLLATE NOCASE
    """, [
      start,end, start,end, start,end, start,end,
      start,end, start,end, start,end, start,end,
    ]);
  }

  Future<Map<String, Object?>> productMarketShare({
    required int userId,
    required int productId,
    required int areaId,
    required String periodStart,
    required String periodEnd,
  }) async {
    final start = _marketDate(periodStart, 'periodStart');
    final end = _marketDate(periodEnd, 'periodEnd');
    if (end.compareTo(start) < 0) throw ArgumentError('periodEnd precedes periodStart');
    await _requireMarketPermission(userId, 'market.analytics.view');
    final db = await database;
    final sales = await db.rawQuery("""
      SELECT
        COALESCE((SELECT SUM(l.base_quantity)
          FROM documents d JOIN document_lines l ON l.document_id=d.id
          WHERE d.kind='issue' AND d.document_type='sale' AND d.status='approved'
            AND l.product_id=? AND substr(COALESCE(d.approved_at,d.created_at),1,10) BETWEEN ? AND ?),0)
        - COALESCE((SELECT SUM(rl.base_quantity)
          FROM documents rd JOIN document_lines rl ON rl.document_id=rd.id
          JOIN document_lines ol ON ol.id=rl.reference_document_line_id
          JOIN documents od ON od.id=ol.document_id
          WHERE rd.kind='return_in' AND rd.status='approved'
            AND od.kind='issue' AND od.document_type='sale'
            AND ol.product_id=? AND substr(COALESCE(rd.approved_at,rd.created_at),1,10) BETWEEN ? AND ?),0)
          AS net_sold_base,
        COALESCE((SELECT SUM(l.entered_quantity*l.unit_price_minor)
          FROM documents d JOIN document_lines l ON l.document_id=d.id
          WHERE d.kind='issue' AND d.document_type='sale' AND d.status='approved'
            AND l.product_id=? AND substr(COALESCE(d.approved_at,d.created_at),1,10) BETWEEN ? AND ?),0)
        - COALESCE((SELECT SUM(rl.entered_quantity*rl.unit_price_minor)
          FROM documents rd JOIN document_lines rl ON rl.document_id=rd.id
          JOIN document_lines ol ON ol.id=rl.reference_document_line_id
          JOIN documents od ON od.id=ol.document_id
          WHERE rd.kind='return_in' AND rd.status='approved'
            AND od.kind='issue' AND od.document_type='sale'
            AND ol.product_id=? AND substr(COALESCE(rd.approved_at,rd.created_at),1,10) BETWEEN ? AND ?),0)
          AS net_sales_minor
    """, [productId,start,end, productId,start,end, productId,start,end, productId,start,end]);
    final marketRows = await db.query(
      'market_size_estimates',
      where: 'product_id=? AND area_id=? AND period_start=? AND period_end=?',
      whereArgs: [productId,areaId,start,end],
      orderBy: 'created_at DESC,id DESC',
      limit: 1,
    );
    final ourQuantity = (sales.first['net_sold_base'] as num).toDouble();
    final ourValue = (sales.first['net_sales_minor'] as num).toDouble();
    if (marketRows.isEmpty) {
      return {
        'has_market_estimate': false,
        'our_net_sold_base': ourQuantity,
        'our_net_sales_minor': ourValue,
      };
    }
    final estimate = marketRows.first;
    final totalQuantity = (estimate['total_market_quantity_base'] as num).toDouble();
    final totalValue = (estimate['total_market_sales_value_minor'] as num?)?.toDouble();
    return {
      'has_market_estimate': true,
      'our_net_sold_base': ourQuantity,
      'our_net_sales_minor': ourValue,
      'total_market_quantity_base': totalQuantity,
      'total_market_sales_value_minor': totalValue,
      'volume_share_percent': totalQuantity > 0 ? ourQuantity / totalQuantity * 100 : null,
      'value_share_percent': totalValue != null && totalValue > 0 ? ourValue / totalValue * 100 : null,
      'confidence_score': estimate['confidence_score'],
      'estimation_method': estimate['estimation_method'],
      'currency_code': estimate['currency_code'],
    };
  }

  Future<List<Map<String, Object?>>> listMarketAreas({required int userId}) async {
    await _requireMarketPermission(userId, 'market.analytics.view');
    final db = await database;
    return db.query('market_areas', where:'is_active=1', orderBy:'area_type,name COLLATE NOCASE');
  }

  Future<int> saveMarketArea({
    required int userId,
    int? parentAreaId,
    String? areaCode,
    required String name,
    required String areaType,
  }) async {
    const types = {'country','city','district','neighborhood','other'};
    if (name.trim().isEmpty || !types.contains(areaType)) {
      throw ArgumentError('A name and valid area type are required');
    }
    await _requireMarketPermission(userId, 'market.demand.manage');
    final db = await database;
    return db.insert('market_areas', {
      'parent_area_id':parentAreaId,
      'area_code':areaCode?.trim().isEmpty == true ? null : areaCode?.trim(),
      'name':name.trim(),
      'area_type':areaType,
      'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveMarketDataSource({
    required int userId,
    required String sourceType,
    required String sourceName,
    String? collectionMethod,
    int? reliabilityScore,
    String? notes,
  }) async {
    const types = {'field_survey','customer_feedback','competitor_observation','supplier_quote','public_report','internal_estimate','other'};
    if (!types.contains(sourceType) || sourceName.trim().isEmpty) {
      throw ArgumentError('A source type and name are required');
    }
    if (reliabilityScore != null && (reliabilityScore < 0 || reliabilityScore > 100)) {
      throw ArgumentError('Reliability score must be between 0 and 100');
    }
    await _requireMarketPermission(userId, 'market.demand.manage');
    final db = await database;
    return db.insert('market_data_sources', {
      'source_type':sourceType,'source_name':sourceName.trim(),
      'collection_method':collectionMethod?.trim(),'reliability_score':reliabilityScore,
      'notes':notes?.trim(),'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveCompetitor({
    required int userId,
    required String name,
    String competitorType = 'direct',
    String? phone,
    String? website,
    String? notes,
  }) async {
    const types = {'direct','indirect','online','wholesale','retail','other'};
    if (name.trim().isEmpty || !types.contains(competitorType)) {
      throw ArgumentError('Competitor name and type are required');
    }
    await _requireMarketPermission(userId, 'market.competitors.manage');
    final db = await database;
    return db.insert('competitors', {
      'name':name.trim(),'competitor_type':competitorType,
      'phone':phone?.trim(),'website':website?.trim(),'notes':notes?.trim(),
      'is_confidential':0,'created_at':DateTime.now().toIso8601String(),
      'updated_at':DateTime.now().toIso8601String(),
    });
  }

  /// Public competitor list only. Confidential records are deliberately omitted
  /// until authenticated permission enforcement is wired into the application.
  Future<List<Map<String, Object?>>> listCompetitorsForUser({required int userId}) async {
    await _requireMarketPermission(userId, 'market.analytics.view');
    final canViewConfidential = await userHasPermission(userId, 'competitor_confidential_view');
    final db = await database;
    return db.query('competitors',
      where:'is_active=1 AND (is_confidential=0 OR ?=1)',
      whereArgs:[canViewConfidential ? 1 : 0],
      orderBy:'name COLLATE NOCASE');
  }

  Future<int> saveCompetitorProduct({
    required int userId,
    required int competitorId,
    int? internalProductId,
    required String externalProductName,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
    String? packageDescription,
    String? observedUnitName,
    double? quantityInInternalBase,
  }) async {
    if (externalProductName.trim().isEmpty ||
        (quantityInInternalBase != null && (!quantityInInternalBase.isFinite || quantityInInternalBase <= 0))) {
      throw ArgumentError('A product name and valid optional unit conversion are required');
    }
    await _requireMarketPermission(userId, 'market.competitors.manage');
    final db = await database;
    final competitor = await db.query('competitors',where:'id=? AND is_active=1 AND is_confidential=0',whereArgs:[competitorId],limit:1);
    if (competitor.isEmpty) throw StateError('Competitor is not available in the public market workspace');
    return db.insert('competitor_products', {
      'competitor_id':competitorId,'internal_product_id':internalProductId,
      'external_product_name':externalProductName.trim(),'brand':brand?.trim(),
      'manufacturer':manufacturer?.trim(),'country_of_origin':countryOfOrigin?.trim(),
      'package_description':packageDescription?.trim(),'observed_unit_name':observedUnitName?.trim(),
      'quantity_in_internal_base':quantityInInternalBase,'is_confidential':0,
      'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> recordCompetitorPrice({
    required int userId,
    required int competitorProductId,
    int? branchId,
    int? dataSourceId,
    required int priceMinor,
    required String currencyCode,
    required double observedQuantityInInternalBase,
    required String observedAt,
    bool taxIncluded = false,
    int? confidenceScore,
    String? notes,
  }) async {
    if (priceMinor < 0 || !observedQuantityInInternalBase.isFinite || observedQuantityInInternalBase <= 0) {
      throw ArgumentError('Price and comparable quantity must be valid');
    }
    final currency = currencyCode.trim().toUpperCase();
    if (currency.length != 3) throw ArgumentError('Currency must be a three-letter code');
    if (confidenceScore != null && (confidenceScore < 0 || confidenceScore > 100)) {
      throw ArgumentError('Confidence score must be between 0 and 100');
    }
    final observed = DateTime.tryParse(observedAt);
    if (observed == null) throw ArgumentError('observedAt must be a valid ISO date/time');
    await _requireMarketPermission(userId, 'market.competitors.manage');
    final db = await database;
    final product = await db.rawQuery("""
      SELECT cp.id FROM competitor_products cp
      JOIN competitors c ON c.id=cp.competitor_id
      WHERE cp.id=? AND cp.is_confidential=0 AND c.is_confidential=0
        AND cp.is_active=1 AND c.is_active=1
    """,[competitorProductId]);
    if (product.isEmpty) throw StateError('Competitor product is not available in the public market workspace');
    return db.insert('competitor_price_observations', {
      'competitor_product_id':competitorProductId,'branch_id':branchId,
      'data_source_id':dataSourceId,'observed_price_minor':priceMinor,
      'currency_code':currency,'observed_quantity_in_internal_base':observedQuantityInInternalBase,
      'tax_included':taxIncluded?1:0,'observed_at':observed.toIso8601String(),
      'confidence_score':confidenceScore,'notes':notes?.trim(),
      'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveMarketSizeEstimate({
    required int userId,
    required int productId,
    required int areaId,
    int? dataSourceId,
    required String periodStart,
    required String periodEnd,
    required double totalMarketQuantityBase,
    required String baseUnitName,
    double? totalMarketSalesValueMinor,
    String? currencyCode,
    required String estimationMethod,
    int? confidenceScore,
    String? notes,
  }) async {
    final start = _marketDate(periodStart, 'periodStart');
    final end = _marketDate(periodEnd, 'periodEnd');
    if (end.compareTo(start) < 0 || !totalMarketQuantityBase.isFinite || totalMarketQuantityBase <= 0) {
      throw ArgumentError('Market period and total quantity must be valid');
    }
    if (baseUnitName.trim().isEmpty || estimationMethod.trim().isEmpty) {
      throw ArgumentError('Base unit and estimation method are required');
    }
    if (confidenceScore != null && (confidenceScore < 0 || confidenceScore > 100)) {
      throw ArgumentError('Confidence score must be between 0 and 100');
    }
    if (totalMarketSalesValueMinor != null &&
        (!totalMarketSalesValueMinor.isFinite || totalMarketSalesValueMinor < 0)) {
      throw ArgumentError('Market value must be non-negative');
    }
    await _requireMarketPermission(userId, 'market.demand.manage');
    final db = await database;
    return db.insert('market_size_estimates', {
      'product_id':productId,'area_id':areaId,'data_source_id':dataSourceId,
      'period_start':start,'period_end':end,
      'total_market_quantity_base':totalMarketQuantityBase,
      'base_unit_name_snapshot':baseUnitName.trim(),
      'total_market_sales_value_minor':totalMarketSalesValueMinor?.round(),
      'currency_code':currencyCode?.trim().toUpperCase(),
      'estimation_method':estimationMethod.trim(),
      'confidence_score':confidenceScore,'notes':notes?.trim(),
      'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> recordUnfulfilledDemand({
    required int userId,
    int? productId,
    required String productName,
    int? areaId,
    int? customerId,
    required double requestedQuantityBase,
    required String baseUnitName,
    required String reasonCode,
    int? competitorId,
    required String requestDate,
    String? notes,
  }) async {
    const reasons = {'out_of_stock','price','not_carried','delivery_limit','quality','other'};
    if (productName.trim().isEmpty || baseUnitName.trim().isEmpty ||
        !requestedQuantityBase.isFinite || requestedQuantityBase <= 0 ||
        !reasons.contains(reasonCode)) {
      throw ArgumentError('Unfulfilled demand details are invalid');
    }
    final date = _marketDate(requestDate,'requestDate');
    await _requireMarketPermission(userId, 'market.demand.manage');
    final db = await database;
    return db.insert('unfulfilled_demand', {
      'product_id':productId,'product_name_snapshot':productName.trim(),
      'area_id':areaId,'customer_id':customerId,
      'requested_quantity_base':requestedQuantityBase,
      'base_unit_name_snapshot':baseUnitName.trim(),
      'reason_code':reasonCode,'competitor_id':competitorId,
      'request_date':date,'created_at':DateTime.now().toIso8601String(),
      'notes':notes?.trim(),
    });
  }

  Future<int> createGrowthOpportunity({
    required int userId,
    int? productId,
    int? areaId,
    required String opportunityType,
    required String title,
    String? description,
    double? estimatedMonthlyDemandBase,
    int? estimatedGrossMarginMinor,
    int? estimatedInvestmentMinor,
    String priority = 'medium',
  }) async {
    const types = {'new_product','increase_supply','price_positioning','new_area','new_segment','competitor_gap','other'};
    const priorities = {'low','medium','high','critical'};
    if (!types.contains(opportunityType) || !priorities.contains(priority) || title.trim().isEmpty) {
      throw ArgumentError('Opportunity type, title and priority are required');
    }
    await _requireMarketPermission(userId, 'market.decisions.manage');
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('growth_opportunities', {
      'product_id':productId,'area_id':areaId,'opportunity_type':opportunityType,
      'title':title.trim(),'description':description?.trim(),
      'estimated_monthly_demand_base':estimatedMonthlyDemandBase,
      'estimated_gross_margin_minor':estimatedGrossMarginMinor,
      'estimated_investment_minor':estimatedInvestmentMinor,
      'priority':priority,'status':'identified','created_at':now,'updated_at':now,
    });
  }

  Future<int> recordMarketDecision({
    required int userId,
    required int opportunityId,
    required String decision,
    double? plannedQuantityBase,
    int? budgetMinor,
    String? targetDate,
    required String rationale,
    int? decidedBy,
  }) async {
    const decisions = {'approved','rejected','deferred','more_research'};
    if (!decisions.contains(decision) || rationale.trim().isEmpty) {
      throw ArgumentError('Decision and rationale are required');
    }
    await _requireMarketPermission(userId, 'market.decisions.manage');
    final db = await database;
    final id = await db.insert('market_decisions', {
      'opportunity_id':opportunityId,'decision':decision,
      'planned_quantity_base':plannedQuantityBase,'budget_minor':budgetMinor,
      'target_date':targetDate == null ? null : _marketDate(targetDate,'targetDate'),
      'rationale':rationale.trim(),'decided_by':decidedBy,
      'decided_at':DateTime.now().toIso8601String(),
    });
    final status = decision == 'approved' ? 'approved'
      : decision == 'rejected' ? 'rejected'
      : decision == 'deferred' ? 'on_hold' : 'under_review';
    await db.update('growth_opportunities', {
      'status':status,'updated_at':DateTime.now().toIso8601String(),
    },where:'id=?',whereArgs:[opportunityId]);
    return id;
  }

  Future<int> saveCompetitorBranch({
    required int userId,
    required int competitorId,
    int? areaId,
    String? branchName,
    String? address,
  }) async {
    await _requireMarketPermission(userId, 'market.competitors.manage');
    final db = await database;
    final competitor = await db.query('competitors',
      where:'id=? AND is_active=1 AND is_confidential=0',
      whereArgs:[competitorId],limit:1);
    if (competitor.isEmpty) throw StateError('Competitor is not available in the public market workspace');
    return db.insert('competitor_branches', {
      'competitor_id':competitorId,'area_id':areaId,
      'branch_name':branchName?.trim(),'address':address?.trim(),
      'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> recordCompetitorAvailability({
    required int userId,
    required int competitorProductId,
    int? branchId,
    int? dataSourceId,
    required String availabilityStatus,
    required String observedAt,
    int? confidenceScore,
    String? notes,
  }) async {
    const statuses = {'available','low_stock','out_of_stock','unknown'};
    if (!statuses.contains(availabilityStatus)) throw ArgumentError('Invalid availability status');
    final observed = DateTime.tryParse(observedAt);
    if (observed == null) throw ArgumentError('observedAt must be a valid ISO date/time');
    if (confidenceScore != null && (confidenceScore < 0 || confidenceScore > 100)) {
      throw ArgumentError('Confidence score must be between 0 and 100');
    }
    await _requireMarketPermission(userId, 'market.competitors.manage');
    final db = await database;
    final product = await db.rawQuery("""
      SELECT cp.id FROM competitor_products cp
      JOIN competitors c ON c.id=cp.competitor_id
      WHERE cp.id=? AND cp.is_confidential=0 AND c.is_confidential=0
        AND cp.is_active=1 AND c.is_active=1
    """,[competitorProductId]);
    if (product.isEmpty) throw StateError('Competitor product is not available in the public market workspace');
    return db.insert('competitor_availability_observations', {
      'competitor_product_id':competitorProductId,'branch_id':branchId,
      'data_source_id':dataSourceId,'availability_status':availabilityStatus,
      'observed_at':observed.toIso8601String(),'confidence_score':confidenceScore,
      'notes':notes?.trim(),'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveMarketDemandObservation({
    required int userId,
    int? productId,
    required String productName,
    required int areaId,
    int? segmentId,
    int? dataSourceId,
    required String observationType,
    required String periodStart,
    required String periodEnd,
    required double demandQuantityBase,
    required String baseUnitName,
    int? estimatedSalesValueMinor,
    String? currencyCode,
    int? confidenceScore,
    String? notes,
  }) async {
    const types = {'observed','surveyed','estimated'};
    final start = _marketDate(periodStart,'periodStart');
    final end = _marketDate(periodEnd,'periodEnd');
    if (!types.contains(observationType) || end.compareTo(start) < 0 ||
        productName.trim().isEmpty || baseUnitName.trim().isEmpty ||
        !demandQuantityBase.isFinite || demandQuantityBase < 0) {
      throw ArgumentError('Market demand observation is invalid');
    }
    if (estimatedSalesValueMinor != null && estimatedSalesValueMinor < 0) {
      throw ArgumentError('Estimated market value must be non-negative');
    }
    if (confidenceScore != null && (confidenceScore < 0 || confidenceScore > 100)) {
      throw ArgumentError('Confidence score must be between 0 and 100');
    }
    await _requireMarketPermission(userId, 'market.demand.manage');
    final db = await database;
    if (productId != null) {
      final products = await db.query('products',
        columns:['name','base_unit_name'],where:'id=?',whereArgs:[productId],limit:1);
      if (products.isEmpty) throw StateError('Product not found');
      if (products.first['base_unit_name'] != baseUnitName.trim()) {
        throw ArgumentError('Demand quantity must use the product base unit');
      }
    }
    return db.insert('market_demand_observations', {
      'product_id':productId,'product_name_snapshot':productName.trim(),
      'area_id':areaId,'segment_id':segmentId,'data_source_id':dataSourceId,
      'observation_type':observationType,'period_start':start,'period_end':end,
      'demand_quantity_base':demandQuantityBase,
      'base_unit_name_snapshot':baseUnitName.trim(),
      'estimated_sales_value_minor':estimatedSalesValueMinor,
      'currency_code':currencyCode?.trim().toUpperCase(),
      'confidence_score':confidenceScore,'notes':notes?.trim(),
      'created_at':DateTime.now().toIso8601String(),
    });
  }

  Future<int> saveProductMarketProfile({
    required int userId,
    required int productId,
    String? brand,
    String? manufacturer,
    String? countryOfOrigin,
    String? customsCode,
    String? storageRequirements,
  }) async {
    await _requireMarketPermission(userId, 'market.demand.manage');
    final db = await database;
    final products = await db.query('products',columns:['id'],
      where:'id=?',whereArgs:[productId],limit:1);
    if (products.isEmpty) throw StateError('Product not found');
    await db.insert('product_market_profiles', {
      'product_id':productId,'brand':brand?.trim(),
      'manufacturer':manufacturer?.trim(),'country_of_origin':countryOfOrigin?.trim(),
      'customs_code':customsCode?.trim(),'storage_requirements':storageRequirements?.trim(),
      'updated_at':DateTime.now().toIso8601String(),
    },conflictAlgorithm:ConflictAlgorithm.replace);
    return productId;
  }

  Future<int> saveSupplierProductTerms({
    required int userId,
    required int supplierId,
    required int productId,
    int? leadTimeDays,
    double? minimumOrderQuantityBase,
    int? quotedUnitCostMinor,
    String? currencyCode,
    String? quoteValidUntil,
    String? notes,
  }) async {
    if (leadTimeDays != null && leadTimeDays < 0) throw ArgumentError('Lead time cannot be negative');
    if (minimumOrderQuantityBase != null &&
        (!minimumOrderQuantityBase.isFinite || minimumOrderQuantityBase <= 0)) {
      throw ArgumentError('Minimum order quantity must be positive');
    }
    if (quotedUnitCostMinor != null && quotedUnitCostMinor < 0) {
      throw ArgumentError('Quoted cost cannot be negative');
    }
    await _requireMarketPermission(userId, 'market.demand.manage');
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('supplier_product_terms', {
      'supplier_id':supplierId,'product_id':productId,
      'lead_time_days':leadTimeDays,
      'minimum_order_quantity_base':minimumOrderQuantityBase,
      'quoted_unit_cost_minor':quotedUnitCostMinor,
      'currency_code':currencyCode?.trim().toUpperCase(),
      'quote_valid_until':quoteValidUntil == null ? null : _marketDate(quoteValidUntil,'quoteValidUntil'),
      'notes':notes?.trim(),'updated_at':now,
    },conflictAlgorithm:ConflictAlgorithm.replace);
    final rows = await db.query('supplier_product_terms',
      columns:['id'],where:'supplier_id=? AND product_id=?',
      whereArgs:[supplierId,productId],limit:1);
    return rows.first['id'] as int;
  }

  Future<List<Map<String, Object?>>> listMarketDemandObservations({
    required int userId,
    int? productId,
    int? areaId,
  }) async {
    await _requireMarketPermission(userId, 'market.analytics.view');
    final db = await database;
    final filters = <String>[];
    final args = <Object?>[];
    if (productId != null) { filters.add('m.product_id=?'); args.add(productId); }
    if (areaId != null) { filters.add('m.area_id=?'); args.add(areaId); }
    return db.rawQuery("""
      SELECT m.*,a.name AS area_name,s.name AS segment_name,src.source_name
      FROM market_demand_observations m
      JOIN market_areas a ON a.id=m.area_id
      LEFT JOIN market_segments s ON s.id=m.segment_id
      LEFT JOIN market_data_sources src ON src.id=m.data_source_id
      ${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}'}
      ORDER BY m.period_start DESC,m.created_at DESC
    """,args);
  }

  Future<List<Map<String, Object?>>> listGrowthOpportunities({
    required int userId,
    String? status,
  }) async {
    await _requireMarketPermission(userId, 'market.analytics.view');
    final db = await database;
    return db.rawQuery("""
      SELECT g.*,p.name AS product_name,a.name AS area_name
      FROM growth_opportunities g
      LEFT JOIN products p ON p.id=g.product_id
      LEFT JOIN market_areas a ON a.id=g.area_id
      ${status == null ? '' : 'WHERE g.status=?'}
      ORDER BY CASE g.priority WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END,
        g.created_at DESC
    """,status == null ? [] : [status]);
  }

}
