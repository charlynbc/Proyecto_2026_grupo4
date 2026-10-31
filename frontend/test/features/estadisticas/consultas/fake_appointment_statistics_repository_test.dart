import 'package:agenda_medica/features/estadisticas/consultas/repositories/appointment_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/consultas/repositories/fake_appointment_statistics_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'appointment_statistics_fixtures.dart';

FakeAppointmentStatisticsRepository _fake() =>
    FakeAppointmentStatisticsRepository(
      latency: Duration.zero,
      clock: () => DateTime.utc(2026, 10, 14, 15),
    );

void main() {
  test('sin parámetros devuelve el ejemplo del contrato con el mes', () async {
    final result = await _fake().statistics();

    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(
      [for (final key in statusKeys) result.counts[key]],
      [40, 110, 20, 8, 14, 5, 3],
    );
    expect(result.total, 200);
    expect(result.cancelledBySocio, 20);
    expect(result.percentage, 10.0);
    expect(result.percentageText, '10 %');
  });

  test('no filtra por otra cosa: repite las fechas pedidas', () async {
    final result = await _fake().statistics(
      from: DateTime.utc(2026, 9, 5),
      to: DateTime.utc(2026, 9, 20),
    );

    expect(result.from, DateTime.utc(2026, 9, 5));
    expect(result.to, DateTime.utc(2026, 9, 20));
    expect(result.total, 200);
  });

  test('con solo desde completa hasta con el fin del mes en curso', () async {
    final result = await _fake().statistics(from: DateTime.utc(2026, 10, 5));

    expect(result.from, DateTime.utc(2026, 10, 5));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.total, 200);
  });

  test('con un solo día devuelve todo en cero y Sin datos', () async {
    final result = await _fake().statistics(
      from: DateTime.utc(2026, 10, 5),
      to: DateTime.utc(2026, 10, 5),
    );

    expect(result.from, DateTime.utc(2026, 10, 5));
    expect(result.to, DateTime.utc(2026, 10, 5));
    expect(
      [for (final key in statusKeys) result.counts[key]],
      [0, 0, 0, 0, 0, 0, 0],
    );
    expect(result.total, 0);
    expect(result.cancelledBySocio, 0);
    expect(result.percentage, isNull);
    expect(result.percentageText, 'Sin datos');
  });

  test('con desde posterior a hasta lanza VALIDACION', () async {
    await expectLater(
      _fake().statistics(
        from: DateTime.utc(2026, 10, 20),
        to: DateTime.utc(2026, 10, 5),
      ),
      throwsA(
        isA<AppointmentStatisticsException>()
            .having(
              (e) => e.failure,
              'failure',
              AppointmentStatisticsFailure.validation,
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
