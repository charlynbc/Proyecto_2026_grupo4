import 'package:agenda_medica/core/validators/uruguayan_ci_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateUruguayanCiVerifierDigit', () {
    test('calcula el verificador para un cuerpo de 7 dígitos', () {
      expect(calculateUruguayanCiVerifierDigit('1234567'), 2);
    });

    test('calcula el verificador para un cuerpo de 6 dígitos con padding', () {
      expect(calculateUruguayanCiVerifierDigit('123456'), 1);
      expect(
        calculateUruguayanCiVerifierDigit('123456'),
        calculateUruguayanCiVerifierDigit('0123456'),
      );
    });
  });

  group('isValidUruguayanCi', () {
    test('acepta una cédula válida de 8 dígitos (cuerpo de 7 + verificador)', () {
      expect(isValidUruguayanCi('12345672'), isTrue);
    });

    test('acepta una cédula válida de 7 dígitos (cuerpo de 6 + verificador)', () {
      expect(isValidUruguayanCi('1234561'), isTrue);
    });

    test('rechaza una cédula con dígito verificador inválido', () {
      expect(isValidUruguayanCi('12345670'), isFalse);
    });

    test('rechaza formatos con longitud inválida', () {
      expect(isValidUruguayanCi('123456'), isFalse);
      expect(isValidUruguayanCi('123456789'), isFalse);
    });

    test('rechaza cadenas con caracteres no numéricos', () {
      expect(isValidUruguayanCi('1234a672'), isFalse);
    });

    test('rechaza cadenas con signos o espacios que int.parse aceptaría', () {
      expect(isValidUruguayanCi('+1234567'), isFalse);
      expect(isValidUruguayanCi(' 1234567'), isFalse);
      expect(isValidUruguayanCi('-1234567'), isFalse);
    });
  });
}
