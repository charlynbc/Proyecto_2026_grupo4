import 'package:agenda_medica/features/turnos/models/suspension_filter.dart';
import 'package:flutter_test/flutter_test.dart';

SuspensionFilter _filter({
  int doctorId = 17,
  int specialtyId = 3,
  DateTime? fromDate,
  DateTime? toDate,
}) => SuspensionFilter(
  doctorId: doctorId,
  specialtyId: specialtyId,
  fromDate: fromDate ?? DateTime.utc(2026, 11, 4),
  toDate: toDate ?? DateTime.utc(2026, 12, 30),
);

void main() {
  group('igualdad por valor', () {
    test('dos filtros con los mismos cuatro campos son iguales', () {
      expect(_filter(), _filter());
      expect(_filter().hashCode, _filter().hashCode);
    });

    test('cambiando el medico dejan de ser iguales', () {
      expect(_filter(doctorId: 18), isNot(_filter()));
    });

    test('cambiando la especialidad dejan de ser iguales', () {
      expect(_filter(specialtyId: 4), isNot(_filter()));
    });

    test('cambiando "desde" dejan de ser iguales', () {
      expect(_filter(fromDate: DateTime.utc(2026, 11, 5)), isNot(_filter()));
    });

    test('cambiando "hasta" dejan de ser iguales', () {
      expect(_filter(toDate: DateTime.utc(2026, 12, 31)), isNot(_filter()));
    });
  });

  group('fromTodayOn', () {
    final today = DateTime.utc(2026, 11, 4);

    test('un "desde" anterior a hoy pasa a ser hoy y el resto no cambia', () {
      final adjusted = _filter(fromDate: DateTime.utc(2026, 10, 1))
          .fromTodayOn(today);

      expect(adjusted, _filter(fromDate: DateTime.utc(2026, 11, 4)));
    });

    test('un "desde" igual a hoy queda igual', () {
      expect(_filter().fromTodayOn(today), _filter());
    });

    test('un "desde" posterior a hoy queda igual', () {
      final filter = _filter(fromDate: DateTime.utc(2026, 11, 10));

      expect(filter.fromTodayOn(today), filter);
    });
  });
}
