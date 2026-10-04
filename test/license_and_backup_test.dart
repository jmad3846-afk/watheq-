import 'package:flutter_test/flutter_test.dart';
import 'package:watheq/core/security/license_service.dart';
import 'package:watheq/core/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('LicenseService Cryptographic Verification Tests', () {
    const testHWID = '8F9A2B3C4D5E6F7A';
    const validExpiryStr = '2028-12-31';
    const expiredStr = '2020-01-01';

    test('AppConstants secretKey matches FactoryProcurement_Secret_Core_Key_9988', () {
      expect(AppConstants.secretKey, equals('FactoryProcurement_Secret_Core_Key_9988'));
    });

    test('generateLicenseKey produces correct format YYYY-MM-DD-CHECKSUM', () {
      final key = LicenseService.generateLicenseKey(
        hwid: testHWID,
        expiryDateStr: validExpiryStr,
        secretKey: AppConstants.secretKey,
      );

      expect(key.startsWith('2028-12-31-'), isTrue);
      expect(key.split('-').length, equals(4));
      expect(key.split('-').last.length, equals(10));
    });

    test('validateLicense validates correct key structure and auto-trims whitespace', () async {
      final generatedKey = LicenseService.generateLicenseKey(
        hwid: await LicenseService.getHWID(),
        expiryDateStr: validExpiryStr,
      );

      // Pass key with whitespace and lowercase letters to test auto-trimming
      final dirtyKey = '  ${generatedKey.toLowerCase()}  ';

      final result = await LicenseService.validateLicense(dirtyKey);
      expect(result.isValid, isTrue);
      expect(result.expiryDateStr, equals(validExpiryStr));
    });

    test('validateLicense rejects invalid checksum', () async {
      final result = await LicenseService.validateLicense('2028-12-31-INVALIDKEY');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('غير مطابق'));
    });

    test('validateLicense detects expired license key', () async {
      final expiredKey = LicenseService.generateLicenseKey(
        hwid: await LicenseService.getHWID(),
        expiryDateStr: expiredStr,
      );

      final result = await LicenseService.validateLicense(expiredKey);
      expect(result.isValid, isFalse);
      expect(result.isExpired, isTrue);
      expect(result.errorMessage, contains('منتهي الصلاحية'));
    });
  });
}
