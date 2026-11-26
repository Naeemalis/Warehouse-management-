import 'package:flutter_test/flutter_test.dart';
import 'package:naeemsoft_wms/security/access_control.dart';

void main() {
  group('AccessControlService input policy', () {
    test('accepts normalized username forms within the supported length', () {
      expect(AccessControlService.isValidUsername('naeem22'), isTrue);
      expect(AccessControlService.isValidUsername('Naeem.Analyst'), isTrue);
      expect(AccessControlService.isValidUsername('ab'), isFalse);
      expect(AccessControlService.isValidUsername('bad name'), isFalse);
      expect(AccessControlService.isValidUsername('name/with/slash'), isFalse);
    });

    test('requires a non-empty password of at least ten characters', () {
      expect(AccessControlService.isValidPassword('StrongPass9'), isTrue);
      expect(AccessControlService.isValidPassword('short123'), isFalse);
      expect(AccessControlService.isValidPassword('          '), isFalse);
    });

    test('competitor permissions are classified as sensitive', () {
      expect(
        AccessControlService.sensitivePermissionKeys,
        containsAll([
          'competitors.view',
          'competitors.edit',
          'competitors.export',
        ]),
      );
      expect(
        AccessControlService.sensitivePermissionKeys,
        isNot(contains('analysis.view')),
      );
    });
  });
}
