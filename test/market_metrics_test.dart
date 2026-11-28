import 'package:flutter_test/flutter_test.dart';
import 'package:naeemsoft_wms/domain/market_metrics.dart';

void main() {
  group('marketSharePercent', () {
    test('calculates volume share', () {
      expect(marketSharePercent(ourQuantity: 200, totalMarketQuantity: 1000), 20);
    });
    test('returns null when market denominator is missing', () {
      expect(marketSharePercent(ourQuantity: 200, totalMarketQuantity: 0), isNull);
    });
  });

  group('demandCoveragePercent', () {
    test('can show coverage above 100 percent without silently capping it', () {
      expect(demandCoveragePercent(fulfilledQuantity: 120, estimatedDemand: 100), 120);
    });
    test('returns null when demand is zero', () {
      expect(demandCoveragePercent(fulfilledQuantity: 0, estimatedDemand: 0), isNull);
    });
  });

  test('competitive price index uses comparable prices', () {
    expect(competitivePriceIndex(ourComparablePrice: 90, competitorComparablePrice: 100), 90);
    expect(competitivePriceIndex(ourComparablePrice: 90, competitorComparablePrice: 0), isNull);
  });

  test('stock cover is undefined when demand history is absent', () {
    expect(stockCoverDays(availableNonExpiredStock: 300, averageDailyDemand: 10), 30);
    expect(stockCoverDays(availableNonExpiredStock: 300, averageDailyDemand: 0), isNull);
  });

  test('reorder point includes lead-time demand and safety stock', () {
    expect(reorderPoint(averageDailyDemand: 8, supplierLeadTimeDays: 5, safetyStock: 12), 52);
  });

  test('gross margin percent uses net sales and cost of goods sold', () {
    expect(grossMarginPercent(netSalesValue: 200, costOfGoodsSold: 150), 25);
    expect(grossMarginPercent(netSalesValue: 0, costOfGoodsSold: 0), isNull);
  });

  test('rejects negative or non-finite inputs', () {
    expect(() => marketSharePercent(ourQuantity: -1, totalMarketQuantity: 10), throwsArgumentError);
    expect(() => reorderPoint(averageDailyDemand: double.infinity, supplierLeadTimeDays: 3, safetyStock: 0), throwsArgumentError);
  });
}
