import 'package:agenda_medica/core/utils/ui_date_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatUiDateTime', () {
    test('muestra el instante en hora de Uruguay, dd/mm/aaaa HH:mm', () {
      // 15:00 UTC es 12:00 en Uruguay.
      expect(
        formatUiDateTime(DateTime.utc(2026, 11, 14, 15)),
        '14/11/2026 12:00',
      );
    });

    test('la medianoche de Uruguay (03:00 UTC) es 00:00 del mismo día', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 12, 1, 3)),
        '01/12/2026 00:00',
      );
    });

    test('las 02:59 UTC son las 23:59 del día anterior', () {
      expect(
        formatUiDateTime(DateTime.utc(2026, 12, 1, 2, 59)),
        '30/11/2026 23:59',
      );
    });

    test('un instante con otro offset se expresa igual en Uruguay', () {
      expect(
        formatUiDateTime(DateTime.parse('2027-01-01T05:00:00+02:00')),
        '01/01/2027 00:00',
      );
    });
  });
}
