import 'package:flutter_test/flutter_test.dart';
import 'package:lenden_tracker/domain/services/phone_number_service.dart';

void main() {
  test(
    'national numbers require an explicit region and normalize to E.164',
    () {
      expect(
        PhoneNumberService.normalize('9876543210', region: 'IN'),
        '+919876543210',
      );
      expect(PhoneNumberService.normalize('9876543210'), isNull);
      expect(PhoneNumberService.normalize('9876543210', region: 'US'), isNull);
    },
  );

  test('international numbers determine their region independently', () {
    final parsed = PhoneNumberService.parse('+1 (650) 253-0000', region: 'IN');
    expect(parsed?.e164, '+16502530000');
    expect(parsed?.region, 'US');
  });

  test(
    'rejects plausible-length but invalid country numbers and extensions',
    () {
      expect(PhoneNumberService.normalize('+919999999'), isNull);
      expect(PhoneNumberService.normalize('+16502530000 ext 12'), isNull);
      expect(PhoneNumberService.normalize('+999123456789'), isNull);
    },
  );
}
