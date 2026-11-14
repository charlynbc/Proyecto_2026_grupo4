import 'package:agenda_medica/core/utils/ui_date_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatUiDateTime pasa el instante a hora de Uruguay', () {
    test('un instante en UTC se muestra tres horas antes', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 10, 16, 14, 20)),
        '16/10/2026 11:20',
      );
    });

    test('un instante con offset -03:00 se muestra tal cual', () {
      expect(
        formatUiDateTime(DateTime.parse('2026-10-16T11:20:00-03:00')),
        '16/10/2026 11:20',
      );
    });

    test('un instante con otro offset se reexpresa en Uruguay', () {
      expect(
        formatUiDateTime(DateTime.parse('2026-10-16T16:20:00+02:00')),
        '16/10/2026 11:20',
      );
    });

    test('a la 01:05 UTC todavía es el día anterior en Uruguay', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 10, 17, 1, 5)),
        '16/10/2026 22:05',
      );
    });

    test('a las 03:00 UTC empieza el día en Uruguay', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 10, 17, 3)),
        '17/10/2026 00:00',
      );
    });

    test('un minuto antes de las 03:00 UTC es el último del día anterior', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 10, 17, 2, 59)),
        '16/10/2026 23:59',
      );
    });

    test('el cambio de día también cambia el año', () {
      expect(
        formatUiDateTime(DateTime.utc(2027, 1, 1, 2, 30)),
        '31/12/2026 23:30',
      );
    });

    test('la hora va de 24 horas, sin AM ni PM', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 10, 16, 21, 45)),
        '16/10/2026 18:45',
      );
    });

    test('día, mes, hora y minuto llevan siempre dos dígitos', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 3, 5, 12, 7)),
        '05/03/2026 09:07',
      );
    });
  });
}
