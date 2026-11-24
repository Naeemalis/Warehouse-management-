double convertToBaseQuantity({required double enteredQuantity, required double factorToBase}) {
  if (!enteredQuantity.isFinite || enteredQuantity <= 0) {
    throw ArgumentError.value(enteredQuantity, 'enteredQuantity', 'Must be a positive finite number');
  }
  if (!factorToBase.isFinite || factorToBase <= 0) {
    throw ArgumentError.value(factorToBase, 'factorToBase', 'Must be a positive finite number');
  }
  return enteredQuantity * factorToBase;
}

void validateUnitDefinitions(List<Map<String, Object?>> units, String baseUnitName) {
  if (units.isEmpty) throw ArgumentError('At least one unit is required');
  final base = units.where((u) => u['unit_name'] == baseUnitName).toList();
  if (base.length != 1 || (base.first['factor_to_base'] as num).toDouble() != 1.0) {
    throw ArgumentError('The base unit must exist exactly once with factor 1');
  }
  final names = <String>{};
  for (final unit in units) {
    final name = (unit['unit_name'] as String?)?.trim() ?? '';
    final factor = (unit['factor_to_base'] as num?)?.toDouble() ?? 0;
    if (name.isEmpty || !names.add(name) || !factor.isFinite || factor <= 0) {
      throw ArgumentError('Unit names must be unique and conversion factors positive');
    }
  }
}

/// Defines one nested packaging chain from largest to smallest.
/// Example: carton=12, pack=12 means 12 packs per carton and 12 pieces per pack.
/// Only the first (largest) unit is the purchase unit. Intermediate sale prices
/// are derived from the base-unit price; the purchase-unit price is independent.
List<Map<String, Object?>> buildHierarchicalUnitDefinitions({
  required String baseUnitName,
  required double baseSalePrice,
  required double supplySalePrice,
  required String definitions,
}) {
  if (!baseSalePrice.isFinite || baseSalePrice <= 0 ||
      !supplySalePrice.isFinite || supplySalePrice <= 0) {
    throw ArgumentError('Both sale prices must be positive');
  }
  final parts = definitions.split(',').where((p) => p.trim().isNotEmpty).toList();
  if (parts.isEmpty) throw ArgumentError('A purchase unit is required');
  final parsed = <({String name, double factor})>[];
  for (final part in parts) {
    final bits = part.split('=');
    if (bits.length != 2 || bits[0].trim().isEmpty) {
      throw FormatException('Use unitName=factor');
    }
    final factor = double.tryParse(bits[1].trim().replaceAll(',', '.'));
    if (factor == null || !factor.isFinite || factor <= 0) {
      throw FormatException('Unit factor must be positive');
    }
    parsed.add((name: bits[0].trim(), factor: factor));
  }
  final rows = <Map<String, Object?>>[
    {'unit_name': baseUnitName.trim(), 'factor_to_base': 1.0,
      'sale_price_minor': (baseSalePrice * 100).round(), 'is_purchase_unit': false}
  ];
  var cumulative = 1.0;
  final factors = List<double>.filled(parsed.length, 1.0);
  for (var i = parsed.length - 1; i >= 0; i--) {
    cumulative *= parsed[i].factor;
    factors[i] = cumulative;
  }
  for (var i = parsed.length - 1; i >= 0; i--) {
    final price = i == 0 ? supplySalePrice : baseSalePrice * factors[i];
    rows.add({
      'unit_name': parsed[i].name,
      'factor_to_base': factors[i],
      'sale_price_minor': (price * 100).round(),
      'is_purchase_unit': i == 0,
    });
  }
  validateUnitDefinitions(rows, baseUnitName);
  return rows;
}
