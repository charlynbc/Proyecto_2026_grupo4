import 'package:agenda_medica/features/estadisticas/turnos/repositories/fake_shift_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/turnos/repositories/shift_statistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakeShiftStatisticsRepository _fake() => FakeShiftStatisticsRepository(
  latency: Duration.zero,
  clock: () => DateTime.utc(2026, 10, 14, 15),
);

void main() {
  test('sin parámetros devuelve el mes del reloj y las cuatro filas', () async {
    final result = await _fake().utilization();

    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.items.map((i) => i.doctor.fullName), [
      'Marta Rodríguez',
      'Jorge Pereira',
      'Laura Gómez',
      'Marta Rodríguez',
    ]);
    expect(result.items.map((i) => i.specialty.name), [
      'Cardiología',
      'Medicina General',
      'Pediatría',
      'Cardiología',
    ]);
    expect(result.items.map((i) => i.clinic.name), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 2',
      'Consultorio 5',
    ]);
    expect(result.items.map((i) => i.weekday), [2, 4, 1, 5]);
    expect(result.items.map((i) => i.occupied), [9, 0, 3, 10]);
    expect(result.items.map((i) => i.offered), [12, 0, 8, 10]);
    expect(result.items.map((i) => i.percentage), [75.0, null, 37.5, 100.0]);
    expect(result.items.map((i) => i.utilization), [
      '75 %',
      'Sin datos',
      '37,5 %',
      '100 %',
    ]);
  });

  test('los ids de turno son distintos', () async {
    final result = await _fake().utilization();

    expect(result.items.map((i) => i.shiftId).toSet(), hasLength(4));
  });

  test('no filtra por fecha: repite las fechas pedidas', () async {
    final result = await _fake().utilization(
      from: DateTime.utc(2026, 9, 5),
      to: DateTime.utc(2026, 9, 20),
    );

    expect(result.from, DateTime.utc(2026, 9, 5));
    expect(result.to, DateTime.utc(2026, 9, 20));
    expect(result.items, hasLength(4));
  });

  test('con solo desde completa hasta con el fin del mes en curso', () async {
    final result = await _fake().utilization(from: DateTime.utc(2026, 10, 5));

    expect(result.from, DateTime.utc(2026, 10, 5));
    expect(result.to, DateTime.utc(2026, 10, 31));
  });

  test('con desde posterior a hasta lanza VALIDACION', () async {
    await expectLater(
      _fake().utilization(
        from: DateTime.utc(2026, 10, 20),
        to: DateTime.utc(2026, 10, 5),
      ),
      throwsA(
        isA<ShiftStatisticsException>()
            .having(
              (e) => e.failure,
              'failure',
              ShiftStatisticsFailure.validation,
            )
            .having(
              (e) => e.message,
              'message',
              'desde no puede ser posterior a hasta',
            ),
      ),
    );
  });
}
