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
