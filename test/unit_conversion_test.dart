import 'package:flutter_test/flutter_test.dart';
import 'package:naeemsoft_wms/domain/unit_conversion.dart';

void main() {
  group('unit conversion', () {
    test('converts cartons into base pieces', () {
      expect(convertToBaseQuantity(enteredQuantity: 3, factorToBase: 24), 72);
    });

    test('converts kilograms into base grams', () {
      expect(convertToBaseQuantity(enteredQuantity: 2.5, factorToBase: 1000), 2500);
    });

    test('rejects zero or negative quantities', () {
      expect(() => convertToBaseQuantity(enteredQuantity: 0, factorToBase: 6), throwsArgumentError);
      expect(() => convertToBaseQuantity(enteredQuantity: 2, factorToBase: -1), throwsArgumentError);
    });

    test('requires a base unit with factor one', () {
      expect(() => validateUnitDefinitions([
        {'unit_name':'piece','factor_to_base':1.0},
        {'unit_name':'carton','factor_to_base':24.0},
      ], 'piece'), returnsNormally);
      expect(() => validateUnitDefinitions([
        {'unit_name':'piece','factor_to_base':2.0},
      ], 'piece'), throwsArgumentError);
    });

    test('rejects duplicate unit names', () {
      expect(() => validateUnitDefinitions([
        {'unit_name':'piece','factor_to_base':1.0},
        {'unit_name':'piece','factor_to_base':6.0},
      ], 'piece'), throwsArgumentError);
    });
  });
}
