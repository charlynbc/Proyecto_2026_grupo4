import 'package:agenda_medica/features/estadisticas/absences/repositories/absence_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/fake_absence_statistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakeAbsenceStatisticsRepository _fake() => FakeAbsenceStatisticsRepository(
  latency: Duration.zero,
  clock: () => DateTime.utc(2026, 10, 14, 15),
);

void main() {
  test('por especialidad devuelve el mes y dos grupos sin apellido', () async {
    final result = await _fake().statistics(
      grouping: AbsenceGrouping.specialty,
    );

    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.groupedBy, 'ESPECIALIDAD');
    expect(result.items.map((item) => item.name), ['Cardiología', 'Pediatría']);
    expect(result.items.map((item) => item.lastName), [null, null]);
    expect(result.items.map((item) => item.id), [3, 2]);
    expect(result.items.map((item) => item.attended), [20, 8]);
    expect(result.items.map((item) => item.noShow), [2, 0]);
    expect(result.items.map((item) => item.missed), [1, 0]);
    expect(result.items.map((item) => item.notAttended), [2, 2]);
    expect(result.items.map((item) => item.total), [25, 10]);
    expect(result.items.map((item) => item.percentage), [12.0, 0.0]);
    expect(result.items.map((item) => item.percentageText), ['12 %', '0 %']);
  });

  test('por médico devuelve otros grupos, con apellido', () async {
    final result = await _fake().statistics(grouping: AbsenceGrouping.doctor);

    expect(result.groupedBy, 'MEDICO');
    expect(result.items.map((item) => item.id), [4, 8]);
    expect(result.items.map((item) => item.name), ['Carla', 'Luis']);
    expect(result.items.map((item) => item.lastName), ['Méndez', 'Gómez']);
    expect(result.items.map((item) => item.attended), [6, 4]);
    expect(result.items.map((item) => item.noShow), [3, 0]);
    expect(result.items.map((item) => item.missed), [1, 0]);
    expect(result.items.map((item) => item.notAttended), [0, 1]);
    expect(result.items.map((item) => item.total), [10, 5]);
    expect(result.items.map((item) => item.percentage), [40.0, 0.0]);
    expect(result.items.map((item) => item.percentageText), ['40 %', '0 %']);
  });

  test('repite las fechas pedidas y no cambia los conteos', () async {
    final result = await _fake().statistics(
      from: DateTime.utc(2026, 9, 5),
      to: DateTime.utc(2026, 9, 20),
      grouping: AbsenceGrouping.specialty,
    );

    expect(result.from, DateTime.utc(2026, 9, 5));
    expect(result.to, DateTime.utc(2026, 9, 20));
    expect(result.items.map((item) => item.total), [25, 10]);
  });

  test('con solo desde completa hasta con el fin del mes en curso', () async {
    final result = await _fake().statistics(
      from: DateTime.utc(2026, 10, 5),
      grouping: AbsenceGrouping.doctor,
    );

    expect(result.from, DateTime.utc(2026, 10, 5));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.groupedBy, 'MEDICO');
  });

  test('con desde posterior a hasta lanza VALIDACION', () async {
    await expectLater(
      _fake().statistics(
        from: DateTime.utc(2026, 10, 20),
        to: DateTime.utc(2026, 10, 5),
        grouping: AbsenceGrouping.specialty,
      ),
      throwsA(
        isA<AbsenceStatisticsException>()
            .having(
              (error) => error.failure,
              'failure',
              AbsenceStatisticsFailure.validation,
            )
            .having(
              (error) => error.message,
              'message',
              'desde no puede ser posterior a hasta',
            ),
      ),
    );
  });
}
