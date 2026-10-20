import 'package:agenda_medica/features/turnos/models/shift_date_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatUiDate', () {
    test('escribe dd/mm/aaaa con ceros a la izquierda', () {
      expect(formatUiDate(DateTime.utc(2026, 10, 5)), '05/10/2026');
      expect(formatUiDate(DateTime.utc(2026, 1, 31)), '31/01/2026');
    });
  });

  group('parseUiDate', () {
    test('lee una fecha válida como clave de día en UTC', () {
      expect(parseUiDate('20/10/2026'), DateTime.utc(2026, 10, 20));
      expect(parseUiDate('20/10/2026')!.isUtc, isTrue);
    });

    test('acepta el 29/02 de un año bisiesto', () {
      expect(parseUiDate('29/02/2028'), DateTime.utc(2028, 2, 29));
    });

    for (final text in [
      '29/02/2026', // 2026 no es bisiesto.
      '31/04/2026', // Abril tiene 30 días.
      '00/10/2026', // No existe el día 0.
      '20/13/2026', // No existe el mes 13.
      '2/10/2026', // Un solo dígito.
      '20-10-2026', // Separador equivocado.
      '20/10/26', // Año de dos dígitos.
      '2026-10-20', // Formato ISO.
      ' 20/10/2026', // Espacio al principio.
      '20/10/2026 ', // Espacio al final.
      '', // Vacío.
    ]) {
      test('rechaza "$text"', () {
        expect(parseUiDate(text), isNull);
      });
    }

    for (final text in [
      '20/10/2026',
      '05/10/2026',
      '29/02/2028',
      '31/12/1999',
    ]) {
      test('ida y vuelta con $text', () {
        expect(formatUiDate(parseUiDate(text)!), text);
      });
    }
  });
}
