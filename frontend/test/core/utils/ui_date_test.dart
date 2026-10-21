import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatUiDate', () {
    test('escribe dd/mm/aaaa con ceros a la izquierda', () {
      expect(formatUiDate(DateTime.utc(2026, 10, 5)), '05/10/2026');
      expect(formatUiDate(DateTime.utc(2026, 1, 31)), '31/01/2026');
    });
  });

  group('hasUiDateFormat', () {
    test('reconoce la forma dd/mm/aaaa, exista o no esa fecha', () {
      expect(hasUiDateFormat('20/10/2026'), isTrue);
      expect(hasUiDateFormat('31/02/2026'), isTrue);
      expect(hasUiDateFormat('00/00/0000'), isTrue);
    });

    test('rechaza cualquier otra forma, sin recortar espacios', () {
      for (final text in [
        '2/10/2026',
        '20-10-2026',
        '20/10/26',
        '2026-10-20',
        ' 20/10/2026',
        '20/10/2026 ',
        '',
      ]) {
        expect(hasUiDateFormat(text), isFalse, reason: '"$text"');
      }
    });
  });

  group('uiDateError', () {
    const badFormat =
        'Escribí la fecha como dd/mm/aaaa, por ejemplo 20/10/2026.';
    const nonexistent =
        'Esa fecha no existe en el calendario. Revisá el día y el mes.';

    test('un texto vacío no es un error: es un campo sin completar', () {
      expect(uiDateError(''), isNull);
    });

    test('una fecha válida no tiene error, tampoco la bisiesta', () {
      expect(uiDateError('20/10/2026'), isNull);
      expect(uiDateError('29/02/2028'), isNull);
    });

    for (final text in [
      'abc',
      '2/10/2026',
      '20-10-2026',
      '20/10/26',
      '2026-10-20',
      ' 20/10/2026',
      '20/10/2026 ',
      '   ',
      '20/10',
    ]) {
      test('"$text" tiene mal el formato', () {
        expect(uiDateError(text), badFormat);
      });
    }

    for (final text in [
      '31/02/2026',
      '29/02/2026',
      '31/04/2026',
      '00/10/2026',
      '20/13/2026',
      '32/01/2026',
    ]) {
      test('"$text" tiene el formato pero esa fecha no existe', () {
        expect(uiDateError(text), nonexistent);
      });
    }

    test(
      'el mensaje de mal formato y el de fecha inexistente son distintos',
      () {
        expect(uiDateError('xx'), isNot(uiDateError('31/02/2026')));
      },
    );

    test('coincide con hasUiDateFormat y parseUiDate', () {
      for (final text in ['20/10/2026', '31/02/2026', 'abc', '']) {
        final error = uiDateError(text);
        if (text.isEmpty || parseUiDate(text) != null) {
          expect(error, isNull, reason: text);
        } else if (hasUiDateFormat(text)) {
          expect(error, nonexistent, reason: text);
        } else {
          expect(error, badFormat, reason: text);
        }
      }
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
