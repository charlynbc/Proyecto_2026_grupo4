import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UruguayTime.today con un instante dado', () {
    test('a la 01:30 UTC todavía es el día anterior en Uruguay', () {
      final today = UruguayTime.today(now: DateTime.utc(2026, 11, 13, 1, 30));

      expect(today, DateTime.utc(2026, 11, 12));
    });

    test('a las 02:59:59 UTC sigue siendo el día anterior', () {
      final today = UruguayTime.today(
        now: DateTime.utc(2026, 11, 13, 2, 59, 59),
      );

      expect(today, DateTime.utc(2026, 11, 12));
    });

    test('a las 03:00 UTC empieza el día en Uruguay', () {
      final today = UruguayTime.today(now: DateTime.utc(2026, 11, 13, 3));

      expect(today, DateTime.utc(2026, 11, 13));
    });

    test('al mediodía UTC es el mismo día', () {
      final today = UruguayTime.today(now: DateTime.utc(2026, 11, 13, 12));

      expect(today, DateTime.utc(2026, 11, 13));
    });

    test('cruza el cambio de mes y de año', () {
      expect(
        UruguayTime.today(now: DateTime.utc(2026, 12, 1, 2)),
        DateTime.utc(2026, 11, 30),
      );
      expect(
        UruguayTime.today(now: DateTime.utc(2027, 1, 1, 2)),
        DateTime.utc(2026, 12, 31),
      );
    });
  });
}
