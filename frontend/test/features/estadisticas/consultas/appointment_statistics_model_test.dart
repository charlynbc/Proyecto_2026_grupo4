import 'package:agenda_medica/features/estadisticas/consultas/models/appointment_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'appointment_statistics_fixtures.dart';

/// Lo que tira `fromJson` ante una respuesta mal formada; el repositorio lo
/// convierte en el error genérico.
final _malformed = anyOf(isA<FormatException>(), isA<TypeError>());

void main() {
  test('lee la respuesta del contrato', () {
    final result = AppointmentStatistics.fromJson(contractBody());

    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.total, 200);
    expect(result.cancelledBySocio, 20);
    expect(result.percentage, 10.0);
    expect(result.percentageText, '10 %');
    expect(result.counts['AGENDADA'], 40);
    expect(result.counts['ATENDIDA'], 110);
    expect(result.counts['CANCELADA_SOCIO'], 20);
    expect(result.counts['CANCELADA_INSTITUCION'], 8);
    expect(result.counts['NO_ASISTIO'], 14);
    expect(result.counts['NO_ATENDIDA'], 5);
    expect(result.counts['NO_SE_PRESENTO'], 3);
    expect(result.counts, hasLength(7));
  });

  test('un porcentaje entero se lee como decimal', () {
    final body = contractBody()..['porcentajeCancelacion'] = 10;

    expect(AppointmentStatistics.fromJson(body).percentage, 10.0);
  });

  test('con total cero el porcentaje es null y el texto Sin datos', () {
    final body = contractBody()
      ..['totalConsultas'] = 0
      ..['canceladasPorSocio'] = 0
      ..['porcentajeCancelacion'] = null
      ..['porcentajeCancelacionTexto'] = 'Sin datos';
    for (final key in statusKeys) {
      statesOf(body)[key] = 0;
    }

    final result = AppointmentStatistics.fromJson(body);

    expect(result.total, 0);
    expect(result.percentage, isNull);
    expect(result.percentageText, 'Sin datos');
  });

  test('con consultas y ninguna cancelada por el socio, 0 %', () {
    final body = contractBody()
      ..['canceladasPorSocio'] = 0
      ..['porcentajeCancelacion'] = 0
      ..['porcentajeCancelacionTexto'] = '0 %';

    final result = AppointmentStatistics.fromJson(body);

    expect(result.percentage, 0.0);
    expect(result.percentageText, '0 %');
  });

  test('el total es el del servidor, no la suma de los estados', () {
    final body = contractBody()..['totalConsultas'] = 201;

    expect(AppointmentStatistics.fromJson(body).total, 201);
  });

  test('el texto de la tasa se conserva sin tocarlo', () {
    final body = contractBody()..['porcentajeCancelacionTexto'] = '9.38 %';

    expect(AppointmentStatistics.fromJson(body).percentageText, '9.38 %');
  });

  group('respuestas mal formadas', () {
    test('con seis claves en estados', () {
      final body = contractBody();
      statesOf(body).remove('NO_SE_PRESENTO');

      expect(() => AppointmentStatistics.fromJson(body), throwsA(_malformed));
    });

    test('con una clave desconocida en lugar de una conocida', () {
      final body = contractBody();
      statesOf(body)
        ..remove('NO_SE_PRESENTO')
        ..['REPROGRAMADA'] = 3;

      expect(() => AppointmentStatistics.fromJson(body), throwsA(_malformed));
    });

    test('con una clave desconocida además de las siete', () {
      final body = contractBody();
      statesOf(body)['REPROGRAMADA'] = 3;

      expect(() => AppointmentStatistics.fromJson(body), throwsA(_malformed));
    });

    test('con un conteo como texto', () {
      final body = contractBody();
      statesOf(body)['ATENDIDA'] = '110';

      expect(() => AppointmentStatistics.fromJson(body), throwsA(_malformed));
    });

    test('sin estados', () {
      final body = contractBody()..remove('estados');

      expect(() => AppointmentStatistics.fromJson(body), throwsA(_malformed));
    });

    test('sin totalConsultas', () {
      final body = contractBody()..remove('totalConsultas');

      expect(() => AppointmentStatistics.fromJson(body), throwsA(_malformed));
    });

    test('con una fecha mal formada', () {
      final body = contractBody()..['hasta'] = '31/10/2026';

      expect(() => AppointmentStatistics.fromJson(body), throwsA(_malformed));
    });
  });

  group('estados', () {
    test('el orden fijo es el de la pantalla', () {
      expect(kStatisticsStatusOrder, statusKeys);
    });

    for (var i = 0; i < statusKeys.length; i++) {
      test('${statusKeys[i]} se muestra como "${statusLabels[i]}"', () {
        expect(statisticsStatusLabel(statusKeys[i]), statusLabels[i]);
      });
    }
  });
}
