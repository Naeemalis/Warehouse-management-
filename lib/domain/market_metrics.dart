/// Pure metric calculations used by Product Performance & Market Intelligence.
///
/// A null result means the denominator/history is insufficient; it must not be
/// displayed as a fabricated zero or infinity.
double? marketSharePercent({
  required double ourQuantity,
  required double totalMarketQuantity,
}) {
  _requireNonNegative(ourQuantity, 'ourQuantity');
  _requireNonNegative(totalMarketQuantity, 'totalMarketQuantity');
  if (totalMarketQuantity == 0) return null;
  return ourQuantity / totalMarketQuantity * 100;
}

double? demandCoveragePercent({
  required double fulfilledQuantity,
  required double estimatedDemand,
}) {
  _requireNonNegative(fulfilledQuantity, 'fulfilledQuantity');
  _requireNonNegative(estimatedDemand, 'estimatedDemand');
  if (estimatedDemand == 0) return null;
  return fulfilledQuantity / estimatedDemand * 100;
}

/// Index 100 means price parity; below 100 means our price is lower.
double? competitivePriceIndex({
  required double ourComparablePrice,
  required double competitorComparablePrice,
}) {
  _requireNonNegative(ourComparablePrice, 'ourComparablePrice');
  _requireNonNegative(competitorComparablePrice, 'competitorComparablePrice');
  if (competitorComparablePrice == 0) return null;
  return ourComparablePrice / competitorComparablePrice * 100;
}

/// Returns null when there is no positive demand history to calculate cover.
double? stockCoverDays({
  required double availableNonExpiredStock,
  required double averageDailyDemand,
}) {
  _requireNonNegative(availableNonExpiredStock, 'availableNonExpiredStock');
  _requireNonNegative(averageDailyDemand, 'averageDailyDemand');
  if (averageDailyDemand == 0) return null;
  return availableNonExpiredStock / averageDailyDemand;
}

double reorderPoint({
  required double averageDailyDemand,
  required int supplierLeadTimeDays,
  required double safetyStock,
}) {
  _requireNonNegative(averageDailyDemand, 'averageDailyDemand');
  _requireNonNegative(safetyStock, 'safetyStock');
  if (supplierLeadTimeDays < 0) {
    throw ArgumentError.value(supplierLeadTimeDays, 'supplierLeadTimeDays');
  }
  return averageDailyDemand * supplierLeadTimeDays + safetyStock;
}

double? grossMarginPercent({
  required double netSalesValue,
  required double costOfGoodsSold,
}) {
  _requireNonNegative(netSalesValue, 'netSalesValue');
  _requireNonNegative(costOfGoodsSold, 'costOfGoodsSold');
  if (netSalesValue == 0) return null;
  return (netSalesValue - costOfGoodsSold) / netSalesValue * 100;
}

void _requireNonNegative(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw ArgumentError.value(value, name, 'Must be finite and non-negative');
  }
}
