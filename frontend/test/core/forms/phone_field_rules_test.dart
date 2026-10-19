import 'package:agenda_medica/core/forms/phone_field_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('phoneStatusOf', () {
    test('acepta celulares y fijos uruguayos y números del exterior con +', () {
      for (final phone in [
        '099 123 456',
        '+598 99 123 456',
        '2123 1234',
        '(02) 123-4567',
        '+34 612345678',
      ]) {
        expect(phoneStatusOf(phone), PhoneStatus.valid, reason: phone);
      }
    });

    test('un número que todavía puede seguir creciendo está incompleto', () {
      for (final phone in [
        '09912345',
        '(02) 123',
        '+',
        '+5',
        '00',
        '1234567',
      ]) {
        expect(phoneStatusOf(phone), PhoneStatus.incomplete, reason: phone);
      }
    });

    test('un número que ya no puede ser válido es inválido', () {
      for (final phone in [
        '12345678',
        '00000000',
        '1234567890123456',
        '099123456789',
        '0000',
      ]) {
        expect(phoneStatusOf(phone), PhoneStatus.invalid, reason: phone);
      }
    });

    test('un número de servicio no se acepta', () {
      expect(phoneStatusOf('0800 1234'), isNot(PhoneStatus.valid));
    });
  });

  group('validateOptionalPhone', () {
    test('vacío o en blanco vale', () {
      expect(validateOptionalPhone(null), isNull);
      expect(validateOptionalPhone(''), isNull);
      expect(validateOptionalPhone('   '), isNull);
    });

    test('un número válido no tiene error', () {
      expect(validateOptionalPhone('099 123 456'), isNull);
      expect(validateOptionalPhone('+598 99 123 456'), isNull);
    });

    test('un número incompleto o inválido muestra el mensaje', () {
      for (final phone in ['09912345', '12345678', '0800 1234']) {
        expect(validateOptionalPhone(phone), kInvalidPhoneMessage);
      }
    });
  });

  group('isPhoneIncomplete', () {
    test('solo es verdadero para el estado incompleto', () {
      expect(isPhoneIncomplete('09912345'), isTrue);
      expect(isPhoneIncomplete('099 123 456'), isFalse);
      expect(isPhoneIncomplete('12345678'), isFalse);
    });
  });
}
