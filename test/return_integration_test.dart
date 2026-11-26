import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:naeemsoft_wms/data/wms_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('customer and supplier returns post stock once and enforce source limits', () async {
    final wms = WmsDatabase.instance;

    final supplierId = await wms.saveParty(supplier: true, name: 'Integration Supplier');
    final customerId = await wms.saveParty(supplier: false, name: 'Integration Customer');
    final productId = await wms.saveProduct(
      name: 'Return Test Item',
      baseUnit: 'piece',
      trackingMode: 'count',
      units: [
        {'unit_name': 'piece', 'factor_to_base': 1.0, 'sale_price_minor': 100, 'is_purchase_unit': false},
        {'unit_name': 'carton', 'factor_to_base': 10.0, 'sale_price_minor': 900, 'is_purchase_unit': true},
      ],
    );

    Future<int> createAndApprove({
      required String kind,
      required String partyType,
      required int partyId,
      required String partyName,
      required String unit,
      required double quantity,
      required int price,
    }) async {
      final id = await wms.createDocument(
        kind: kind,
        partyType: partyType,
        partyId: partyId,
        partyName: partyName,
        createdBy: 1,
        lines: [
          {'product_id': productId, 'unit_name': unit, 'quantity': quantity, 'unit_price_minor': price},
        ],
      );
      await wms.submitDocument(documentId: id, userId: 1);
      await wms.approveDocument(documentId: id, approverId: 1);
      return id;
    }

    final receiptId = await createAndApprove(
      kind: 'receipt',
      partyType: 'supplier',
      partyId: supplierId,
      partyName: 'Integration Supplier',
      unit: 'carton',
      quantity: 1,
      price: 1000,
    );
    final issueId = await createAndApprove(
      kind: 'issue',
      partyType: 'customer',
      partyId: customerId,
      partyName: 'Integration Customer',
      unit: 'piece',
      quantity: 5,
      price: 100,
    );

    final issueDetails = await wms.documentDetails(issueId);
    final issueLines = issueDetails['lines'] as List<Map<String, Object?>>;
    final issueLineId = issueLines.single['id'] as int;

    Future<void> createSubmitApproveReturn({
      required int sourceDocumentId,
      required int sourceLineId,
      required String kind,
      required int quantity,
    }) async {
      final returnId = await wms.createReturnDocument(
        originalDocumentId: sourceDocumentId,
        kind: kind,
        createdBy: 1,
        lines: [
          {'source_line_id': sourceLineId, 'quantity': quantity, 'reason': 'Integration test'},
        ],
      );
      await wms.submitDocument(documentId: returnId, userId: 1);
      await wms.approveDocument(documentId: returnId, approverId: 1);
    }

    await createSubmitApproveReturn(
      sourceDocumentId: issueId,
      sourceLineId: issueLineId,
      kind: 'return_in',
      quantity: 2,
    );

    await expectLater(
      wms.createReturnDocument(
        originalDocumentId: issueId,
        kind: 'return_in',
        createdBy: 1,
        lines: [
          {'source_line_id': issueLineId, 'quantity': 4, 'reason': 'Over-return attempt'},
        ],
      ),
      throwsStateError,
    );

    await createSubmitApproveReturn(
      sourceDocumentId: issueId,
      sourceLineId: issueLineId,
      kind: 'return_in',
      quantity: 3,
    );

    final receiptDetails = await wms.documentDetails(receiptId);
    final receiptLines = receiptDetails['lines'] as List<Map<String, Object?>>;
    final receiptLineId = receiptLines.single['id'] as int;

    await createSubmitApproveReturn(
      sourceDocumentId: receiptId,
      sourceLineId: receiptLineId,
      kind: 'return_out',
      quantity: 2,
    );

    await expectLater(
      wms.createReturnDocument(
        originalDocumentId: receiptId,
        kind: 'return_out',
        createdBy: 1,
        lines: [
          {'source_line_id': receiptLineId, 'quantity': 9, 'reason': 'Over-return attempt'},
        ],
      ),
      throwsStateError,
    );

    final products = await wms.listProducts();
    final product = products.singleWhere((row) => row['id'] == productId);
    expect((product['stock_base'] as num).toDouble(), 3);

    final returnableIssueLines = await wms.returnableDocumentLines(issueId);
    expect((returnableIssueLines.single['remaining_base'] as num).toDouble(), 0);

    final returnableReceiptLines = await wms.returnableDocumentLines(receiptId);
    expect((returnableReceiptLines.single['remaining_base'] as num).toDouble(), 8);
  });
}
