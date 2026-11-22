import 'package:flutter_test/flutter_test.dart';
import 'package:naeemsoft_wms/src/services/stock_workflows.dart';

void main() {
  group('Stock quantity conversion', () {
    test('converts entered quantity into the product base unit', () {
      expect(StockWorkflows.toBase(2, 12), 24);
      expect(StockWorkflows.toBase(0.25, 1000), 250);
    });

    test('rejects zero, negative and non-finite quantities', () {
      expect(() => StockWorkflows.toBase(0, 1), throwsArgumentError);
      expect(() => StockWorkflows.toBase(-1, 1), throwsArgumentError);
      expect(() => StockWorkflows.toBase(double.infinity, 1), throwsArgumentError);
      expect(() => StockWorkflows.toBase(1, 0), throwsArgumentError);
    });
  });
}
