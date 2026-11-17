import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UruguayTime.fromUruguay: día y hora de Uruguay a un instante', () {
    test('la medianoche de Uruguay son las 03:00 UTC', () {
      expect(
        UruguayTime.fromUruguay(DateTime.utc(2027, 1, 1), 0, 0),
        DateTime.utc(2027, 1, 1, 3),
      );
    });

    test('las 23:59 de Uruguay ya son el día siguiente en UTC', () {
      expect(
        UruguayTime.fromUruguay(DateTime.utc(2026, 12, 31), 23, 59),
        DateTime.utc(2027, 1, 1, 2, 59),
      );
    });

    test('el mediodía de Uruguay son las 15:00 UTC', () {
      expect(
        UruguayTime.fromUruguay(DateTime.utc(2026, 10, 20), 12, 0),
        DateTime.utc(2026, 10, 20, 15),
      );
    });

    test('ignora la hora de la clave de día', () {
      expect(
        UruguayTime.fromUruguay(DateTime.utc(2026, 10, 20, 17, 45), 9, 30),
        DateTime.utc(2026, 10, 20, 12, 30),
      );
    });
  });

  group('UruguayTime.toIso: un instante con desfase -03:00', () {
    test('las 03:00 UTC son la medianoche de Uruguay', () {
      expect(
        UruguayTime.toIso(DateTime.utc(2027, 1, 1, 3)),
        '2027-01-01T00:00:00-03:00',
      );
    });

    test('las 02:59 UTC son las 23:59 del día anterior', () {
      expect(
        UruguayTime.toIso(DateTime.utc(2027, 1, 1, 2, 59)),
        '2026-12-31T23:59:00-03:00',
      );
    });

    test('lleva los segundos y dos dígitos en cada campo', () {
      expect(
        UruguayTime.toIso(DateTime.utc(2026, 3, 5, 12, 7, 9)),
        '2026-03-05T09:07:09-03:00',
      );
    });

    test('un instante con otro offset se expresa igual en Uruguay', () {
      expect(
        UruguayTime.toIso(DateTime.parse('2026-10-20T16:20:00+02:00')),
        '2026-10-20T11:20:00-03:00',
      );
    });
  });
}
