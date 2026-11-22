import 'package:sqflite/sqflite.dart';

class StockWorkflows {
  StockWorkflows(this.db);
  final Database db;

  static double toBase(double quantity, double factorToBase) {
    if (!quantity.isFinite || quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Must be a positive finite number');
    }
    if (!factorToBase.isFinite || factorToBase <= 0) {
      throw ArgumentError.value(factorToBase, 'factorToBase', 'Must be positive and finite');
    }
    return quantity * factorToBase;
  }

  Future<int> createReceiving({
    required String documentNo,
    required int supplierId,
    required String date,
    required List<Map<String, Object?>> lines,
  }) async {
    if (lines.isEmpty) throw ArgumentError('Receiving document requires at least one line');
    return db.transaction((txn) async {
      final id = await txn.insert('receiving_documents', {
        'document_no': documentNo, 'supplier_id': supplierId,
        'document_date': date, 'status': 'draft',
      });
      for (final line in lines) {
        final quantity = (line['entered_quantity'] as num).toDouble();
        final factor = (line['factor_to_base'] as num).toDouble();
        final cost = line['unit_cost_minor'] as int;
        final base = toBase(quantity, factor);
        await txn.insert('receiving_lines', {
          'receiving_id': id, 'product_id': line['product_id'],
          'entered_unit_id': line['entered_unit_id'],
          'entered_quantity': quantity, 'factor_to_base': factor,
          'received_base_quantity': base, 'unit_cost_minor': cost,
          'line_total_minor': (cost * quantity).round(),
        });
      }
      await _audit(txn, 'CREATE_DRAFT', 'receiving', id);
      return id;
    });
  }

  Future<void> approveReceiving(int documentId, {int? userId}) async {
    await db.transaction((txn) async {
      final doc = await _document(txn, 'receiving_documents', documentId);
      _requireStatus(doc, 'draft', 'pending_approval');
      final lines = await txn.query('receiving_lines', where: 'receiving_id=?', whereArgs: [documentId]);
      if (lines.isEmpty) throw StateError('Cannot approve an empty receiving document');
      for (final line in lines) {
        final batchId = await txn.insert('stock_batches', {
          'receiving_line_id': line['id'], 'product_id': line['product_id'],
          'received_base_quantity': line['received_base_quantity'],
          'remaining_base_quantity': line['received_base_quantity'],
          'unit_cost_minor': line['unit_cost_minor'], 'received_at': doc['document_date'],
        });
        await _movement(txn, productId: line['product_id'] as int, batchId: batchId,
          type: 'RECEIPT', direction: 'IN',
          quantity: (line['received_base_quantity'] as num).toDouble(),
          sourceType: 'receiving', sourceId: documentId, sourceLineId: line['id'] as int, userId: userId);
      }
      await txn.update('receiving_documents', {
        'status': 'approved', 'approved_by': userId, 'approved_at': DateTime.now().toIso8601String(),
      }, where: 'id=?', whereArgs: [documentId]);
      await _audit(txn, 'APPROVE', 'receiving', documentId, userId: userId);
    });
  }

  Future<int> createIssue({
    required String documentNo,
    required String date,
    int? recipientId,
    required List<Map<String, Object?>> lines,
  }) async {
    if (lines.isEmpty) throw ArgumentError('Issue document requires at least one line');
    return db.transaction((txn) async {
      final id = await txn.insert('issue_documents', {
        'document_no': documentNo, 'recipient_id': recipientId,
        'document_date': date, 'status': 'draft',
      });
      for (final line in lines) {
        final quantity = (line['entered_quantity'] as num).toDouble();
        final factor = (line['factor_to_base'] as num).toDouble();
        await txn.insert('issue_lines', {
          'issue_id': id, 'product_id': line['product_id'],
          'entered_unit_id': line['entered_unit_id'], 'entered_quantity': quantity,
          'factor_to_base': factor, 'issue_base_quantity': toBase(quantity, factor),
        });
      }
      await _audit(txn, 'CREATE_DRAFT', 'issue', id);
      return id;
    });
  }

  Future<void> approveIssue(int documentId, {int? userId}) async {
    await db.transaction((txn) async {
      final doc = await _document(txn, 'issue_documents', documentId);
      _requireStatus(doc, 'draft', 'pending_approval');
      final lines = await txn.query('issue_lines', where: 'issue_id=?', whereArgs: [documentId]);
      if (lines.isEmpty) throw StateError('Cannot approve an empty issue document');
      for (final line in lines) {
        var required = (line['issue_base_quantity'] as num).toDouble();
        final batches = await txn.query('stock_batches',
          where: 'product_id=? AND remaining_base_quantity>0',
          whereArgs: [line['product_id']], orderBy: 'received_at ASC, id ASC');
        for (final batch in batches) {
          if (required <= 0) break;
          final available = (batch['remaining_base_quantity'] as num).toDouble();
          final take = available < required ? available : required;
          await txn.update('stock_batches', {'remaining_base_quantity': available - take},
            where: 'id=?', whereArgs: [batch['id']]);
          await _movement(txn, productId: line['product_id'] as int, batchId: batch['id'] as int,
            type: 'ISSUE', direction: 'OUT', quantity: take,
            sourceType: 'issue', sourceId: documentId, sourceLineId: line['id'] as int, userId: userId);
          required -= take;
        }
        if (required > 0.0000001) {
          throw StateError('Insufficient stock for product ${line['product_id']}');
        }
      }
      await txn.update('issue_documents', {
        'status': 'approved', 'approved_by': userId, 'approved_at': DateTime.now().toIso8601String(),
      }, where: 'id=?', whereArgs: [documentId]);
      await _audit(txn, 'APPROVE', 'issue', documentId, userId: userId);
    });
  }

  Future<void> approveSupplierReturn(int returnId, {int? userId}) async {
    await db.transaction((txn) async {
      final doc = await _document(txn, 'supplier_returns', returnId);
      _requireStatus(doc, 'draft', 'pending_approval');
      final lines = await txn.query('supplier_return_lines', where: 'return_id=?', whereArgs: [returnId]);
      if (lines.isEmpty) throw StateError('Cannot approve an empty return');
      for (final line in lines) {
        final prior = await txn.rawQuery(
          'SELECT COALESCE(SUM(return_base_quantity),0) AS qty FROM supplier_return_lines l JOIN supplier_returns r ON r.id=l.return_id WHERE l.receiving_line_id=? AND r.status=?',
          [line['receiving_line_id'], 'approved'],
        );
        final original = await txn.query('receiving_lines', where: 'id=?', whereArgs: [line['receiving_line_id']]);
        if (original.isEmpty) throw StateError('Original receiving line not found');
        final received = (original.first['received_base_quantity'] as num).toDouble();
        final returned = (prior.first['qty'] as num).toDouble();
        final requested = (line['return_base_quantity'] as num).toDouble();
        if (returned + requested > received + 0.0000001) {
          throw StateError('Supplier return exceeds the remaining received quantity');
        }
        final batch = (await txn.query('stock_batches', where: 'id=?', whereArgs: [line['batch_id']])).first;
        final remaining = (batch['remaining_base_quantity'] as num).toDouble();
        if (requested > remaining + 0.0000001) throw StateError('Insufficient stock in original batch');
        await txn.update('stock_batches', {'remaining_base_quantity': remaining - requested},
          where: 'id=?', whereArgs: [line['batch_id']]);
        await _movement(txn, productId: line['product_id'] as int, batchId: line['batch_id'] as int,
          type: 'SUPPLIER_RETURN', direction: 'OUT', quantity: requested,
          sourceType: 'supplier_return', sourceId: returnId, sourceLineId: line['id'] as int, userId: userId);
      }
      await txn.update('supplier_returns', {
        'status': 'approved', 'approved_by': userId, 'approved_at': DateTime.now().toIso8601String(),
      }, where: 'id=?', whereArgs: [returnId]);
      await _audit(txn, 'APPROVE', 'supplier_return', returnId, userId: userId);
    });
  }

  Future<void> startInventoryCount(int countId) async {
    await db.transaction((txn) async {
      final doc = await _document(txn, 'inventory_counts', countId);
      _requireStatus(doc, 'draft');
      final active = await txn.query('inventory_counts', where: "status='active'");
      if (active.isNotEmpty) throw StateError('Another inventory count is already active');
      final products = await txn.query('products', where: 'is_active=1');
      for (final product in products) {
        final rows = await txn.rawQuery(
          'SELECT COALESCE(SUM(remaining_base_quantity),0) AS qty FROM stock_batches WHERE product_id=?',
          [product['id']],
        );
        await txn.insert('inventory_count_lines', {
          'count_id': countId, 'product_id': product['id'],
          'system_quantity_base': rows.first['qty'],
        });
      }
      await txn.update('inventory_counts', {
        'status': 'active', 'started_at': DateTime.now().toIso8601String(),
      }, where: 'id=?', whereArgs: [countId]);
      await _audit(txn, 'START_AND_FREEZE', 'inventory_count', countId);
    });
  }

  Future<void> approveInventoryCount(int countId, {int? userId}) async {
    await db.transaction((txn) async {
      final doc = await _document(txn, 'inventory_counts', countId);
      _requireStatus(doc, 'active', 'pending_approval');
      final lines = await txn.query('inventory_count_lines', where: 'count_id=?', whereArgs: [countId]);
      if (lines.any((line) => line['counted_quantity_base'] == null)) {
        throw StateError('Every product must have a counted quantity before approval');
      }
      for (final line in lines) {
        final systemQty = (line['system_quantity_base'] as num).toDouble();
        final countedQty = (line['counted_quantity_base'] as num).toDouble();
        final difference = countedQty - systemQty;
        await txn.update('inventory_count_lines', {'difference_base': difference},
          where: 'id=?', whereArgs: [line['id']]);
        if (difference.abs() < 0.0000001) continue;
        if (difference < 0) {
          var loss = -difference;
          final batches = await txn.query('stock_batches',
            where: 'product_id=? AND remaining_base_quantity>0',
            whereArgs: [line['product_id']], orderBy: 'received_at ASC, id ASC');
          for (final batch in batches) {
            if (loss <= 0) break;
            final available = (batch['remaining_base_quantity'] as num).toDouble();
            final take = available < loss ? available : loss;
            await txn.update('stock_batches', {'remaining_base_quantity': available - take},
              where: 'id=?', whereArgs: [batch['id']]);
            await _movement(txn, productId: line['product_id'] as int, batchId: batch['id'] as int,
              type: 'COUNT_LOSS', direction: 'OUT', quantity: take,
              sourceType: 'inventory_count', sourceId: countId, sourceLineId: line['id'] as int, userId: userId,
              bypassCountFreeze: true);
            loss -= take;
          }
        } else {
          final batchId = await txn.insert('stock_batches', {
            'receiving_line_id': await _syntheticReceivingLine(txn, line['product_id'] as int, difference),
            'product_id': line['product_id'], 'received_base_quantity': difference,
            'remaining_base_quantity': difference, 'unit_cost_minor': 0,
            'received_at': DateTime.now().toIso8601String(),
          });
          await _movement(txn, productId: line['product_id'] as int, batchId: batchId,
            type: 'COUNT_GAIN', direction: 'IN', quantity: difference,
            sourceType: 'inventory_count', sourceId: countId, sourceLineId: line['id'] as int, userId: userId,
            bypassCountFreeze: true);
        }
      }
      await txn.update('inventory_counts', {
        'status': 'approved', 'approved_by': userId, 'approved_at': DateTime.now().toIso8601String(),
        'closed_at': DateTime.now().toIso8601String(),
      }, where: 'id=?', whereArgs: [countId]);
      await _audit(txn, 'APPROVE_AND_UNFREEZE', 'inventory_count', countId, userId: userId);
    });
  }

  Future<int> _syntheticReceivingLine(Transaction txn, int productId, double qty) async {
    final unit = await txn.query('products', columns: ['base_unit_id'], where: 'id=?', whereArgs: [productId]);
    if (unit.isEmpty) throw StateError('Product not found');
    final supplier = await txn.rawQuery("SELECT id FROM suppliers ORDER BY id LIMIT 1");
    if (supplier.isEmpty) throw StateError('Create a system supplier before posting count gains');
    final docId = await txn.insert('receiving_documents', {
      'document_no': 'COUNT-GAIN-${DateTime.now().microsecondsSinceEpoch}',
      'supplier_id': supplier.first['id'], 'document_date': DateTime.now().toIso8601String(),
      'status': 'approved',
    });
    return txn.insert('receiving_lines', {
      'receiving_id': docId, 'product_id': productId, 'entered_unit_id': unit.first['base_unit_id'],
      'entered_quantity': qty, 'factor_to_base': 1, 'received_base_quantity': qty,
      'unit_cost_minor': 0, 'line_total_minor': 0,
    });
  }

  Future<double> availableStock(int productId) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(remaining_base_quantity),0) AS qty FROM stock_batches WHERE product_id=?',
      [productId],
    );
    return (rows.first['qty'] as num).toDouble();
  }

  Future<Map<String, Object?>> _document(Transaction txn, String table, int id) async {
    final rows = await txn.query(table, where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Document not found');
    return rows.first;
  }

  void _requireStatus(Map<String, Object?> doc, String first, [String? second]) {
    final status = doc['status'];
    if (status != first && status != second) {
      throw StateError('Document status does not allow this operation: $status');
    }
  }

  Future<void> _movement(Transaction txn, {
    required int productId, required int batchId, required String type,
    required String direction, required double quantity, required String sourceType,
    required int sourceId, required int sourceLineId, int? userId,
    bool bypassCountFreeze = false,
  }) async {
    if (!bypassCountFreeze) {
      final active = await txn.query('inventory_counts', where: "status='active'");
      if (active.isNotEmpty) throw StateError('Inventory is frozen while a count is active');
    }
    await txn.insert('stock_movements', {
      'product_id': productId, 'batch_id': batchId, 'movement_type': type,
      'direction': direction, 'quantity_base': quantity, 'source_type': sourceType,
      'source_id': sourceId, 'source_line_id': sourceLineId, 'created_by': userId,
    });
  }

  Future<void> _audit(Transaction txn, String action, String type, int id, {int? userId}) async {
    await txn.insert('audit_log', {
      'user_id': userId, 'action': action, 'entity_type': type, 'entity_id': id,
    });
  }
}
