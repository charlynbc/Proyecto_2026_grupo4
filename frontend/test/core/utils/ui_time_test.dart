import 'package:agenda_medica/core/utils/ui_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseUiTime', () {
    test('lee horas válidas de 24 horas', () {
      expect(parseUiTime('00:00'), (hour: 0, minute: 0));
      expect(parseUiTime('09:05'), (hour: 9, minute: 5));
      expect(parseUiTime('18:30'), (hour: 18, minute: 30));
      expect(parseUiTime('23:59'), (hour: 23, minute: 59));
    });

    test('rechaza horas y minutos fuera de rango', () {
      expect(parseUiTime('24:00'), isNull);
      expect(parseUiTime('12:60'), isNull);
      expect(parseUiTime('99:99'), isNull);
    });

    test('rechaza lo que no tiene la forma HH:mm', () {
      expect(parseUiTime(''), isNull);
      expect(parseUiTime('9:05'), isNull);
      expect(parseUiTime('09:5'), isNull);
      expect(parseUiTime('0905'), isNull);
      expect(parseUiTime('09:05:00'), isNull);
      expect(parseUiTime(' 09:05'), isNull);
      expect(parseUiTime('09.05'), isNull);
      expect(parseUiTime('9:05 PM'), isNull);
    });
  });

  group('uiTimeError', () {
    test('un texto vacío no es un error', () {
      expect(uiTimeError(''), isNull);
    });

    test('una hora válida no es un error', () {
      expect(uiTimeError('23:59'), isNull);
    });

    test('una hora mal escrita dice cómo escribirla', () {
      expect(
        uiTimeError('9:5'),
        'Escribí la hora como HH:mm, de 00:00 a 23:59, por ejemplo 18:30.',
      );
      expect(uiTimeError('24:00'), kUiTimeBadFormatMessage);
      expect(uiTimeError('12:60'), kUiTimeBadFormatMessage);
    });
  });

  group('formatUiTime', () {
    test('lleva siempre dos dígitos y es de 24 horas', () {
      expect(formatUiTime(0, 0), '00:00');
      expect(formatUiTime(9, 5), '09:05');
      expect(formatUiTime(23, 59), '23:59');
      expect(formatUiTime(18, 30), '18:30');
    });
  });

  test('hasUiTimeFormat mira solo la forma, no el rango', () {
    expect(hasUiTimeFormat('99:99'), isTrue);
    expect(hasUiTimeFormat('9:99'), isFalse);
  });
}
