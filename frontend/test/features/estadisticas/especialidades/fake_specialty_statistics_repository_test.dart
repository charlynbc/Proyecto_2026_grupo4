import 'package:agenda_medica/features/estadisticas/especialidades/repositories/fake_specialty_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/repositories/specialty_statistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakeSpecialtyStatisticsRepository _fake() => FakeSpecialtyStatisticsRepository(
  latency: Duration.zero,
  clock: () => DateTime.utc(2026, 10, 14, 15),
);

void main() {
  test('sin parámetros devuelve el mes del reloj y las cuatro filas', () async {
    final demand = await _fake().demand();

    expect(demand.from, DateTime.utc(2026, 10, 1));
    expect(demand.to, DateTime.utc(2026, 10, 31));
    expect(demand.items.map((i) => i.specialty.name), [
      'Medicina General',
      'Cardiología',
      'Dermatología',
      'Pediatría',
    ]);
    expect(demand.items.map((i) => i.count), [128, 42, 7, 0]);
    expect(demand.items.map((i) => i.specialty.requiresReferral), [
      false,
      true,
      true,
      false,
    ]);
    expect(demand.total, 177);
  });

  test('no filtra por fecha: repite las fechas pedidas', () async {
    final demand = await _fake().demand(
      from: DateTime.utc(2026, 9, 5),
      to: DateTime.utc(2026, 9, 20),
    );

    expect(demand.from, DateTime.utc(2026, 9, 5));
    expect(demand.to, DateTime.utc(2026, 9, 20));
    expect(demand.items.map((i) => i.count), [128, 42, 7, 0]);
  });

  test('con solo desde completa hasta con el fin del mes en curso', () async {
    final demand = await _fake().demand(from: DateTime.utc(2026, 10, 5));

    expect(demand.from, DateTime.utc(2026, 10, 5));
    expect(demand.to, DateTime.utc(2026, 10, 31));
  });

  test('con desde posterior a hasta lanza VALIDACION', () async {
    await expectLater(
      _fake().demand(
        from: DateTime.utc(2026, 10, 20),
        to: DateTime.utc(2026, 10, 5),
      ),
      throwsA(
        isA<SpecialtyStatisticsException>()
            .having(
              (e) => e.failure,
              'failure',
              SpecialtyStatisticsFailure.validation,
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
