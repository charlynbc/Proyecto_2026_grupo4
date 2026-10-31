import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/estadisticas/consultas/repositories/api_appointment_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/consultas/repositories/appointment_statistics_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'appointment_statistics_fixtures.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object? body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiAppointmentStatisticsRepository, _Adapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiAppointmentStatisticsRepository(dio), adapter);
}

TypeMatcher<AppointmentStatisticsException> _failure(
  AppointmentStatisticsFailure failure,
) => isA<AppointmentStatisticsException>().having(
  (e) => e.failure,
  'failure',
  failure,
);

/// El error genérico: un `ApiException` común, no uno de los casos que la
/// pantalla distingue.
Matcher _generic() => isA<ApiException>()
    .having((e) => e.message, 'message', kApiGenericMessage)
    .having(
      (e) => e is AppointmentStatisticsException,
      'es AppointmentStatisticsException',
      isFalse,
    );

void main() {
  test('sin parámetros pide la ruta sin query y parsea la respuesta', () async {
    final (repository, adapter) = _repository(200, contractBody());

    final result = await repository.statistics();

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/estadisticas/consultas');
    expect(adapter.last!.queryParameters, isEmpty);
    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.total, 200);
    expect(result.percentageText, '10 %');
    expect(result.counts['ATENDIDA'], 110);
  });

  test('con las dos fechas manda desde y hasta como YYYY-MM-DD', () async {
    final (repository, adapter) = _repository(200, contractBody());

    await repository.statistics(
      from: DateTime.utc(2026, 10, 5),
      to: DateTime.utc(2026, 10, 20),
    );

    expect(adapter.last!.queryParameters, {
      'desde': '2026-10-05',
      'hasta': '2026-10-20',
    });
  });

  test('con solo desde manda solo desde', () async {
    final (repository, adapter) = _repository(200, contractBody());

    await repository.statistics(from: DateTime.utc(2026, 10, 5));

    expect(adapter.last!.queryParameters, {'desde': '2026-10-05'});
  });

  test('con solo hasta manda solo hasta', () async {
    final (repository, adapter) = _repository(200, contractBody());

    await repository.statistics(to: DateTime.utc(2026, 10, 20));

    expect(adapter.last!.queryParameters, {'hasta': '2026-10-20'});
  });

  test('un porcentaje entero en la respuesta no es un error', () async {
    final body = contractBody()..['porcentajeCancelacion'] = 10;
    final (repository, _) = _repository(200, body);

    final result = await repository.statistics();

    expect(result.percentage, 10.0);
  });

  test('con total cero lee el porcentaje null y Sin datos', () async {
    final body = contractBody()
      ..['totalConsultas'] = 0
      ..['canceladasPorSocio'] = 0
      ..['porcentajeCancelacion'] = null
      ..['porcentajeCancelacionTexto'] = 'Sin datos';
    final (repository, _) = _repository(200, body);

    final result = await repository.statistics();

    expect(result.percentage, isNull);
    expect(result.percentageText, 'Sin datos');
  });

  group('una respuesta inválida da el error genérico', () {
    test('con seis estados', () async {
      final body = contractBody();
      statesOf(body).remove('NO_ATENDIDA');
      final (repository, _) = _repository(200, body);
      await expectLater(repository.statistics(), throwsA(_generic()));
    });

    test('con un estado desconocido (REPROGRAMADA)', () async {
      final body = contractBody();
      statesOf(body)
        ..remove('NO_SE_PRESENTO')
        ..['REPROGRAMADA'] = 3;
      final (repository, _) = _repository(200, body);
      await expectLater(repository.statistics(), throwsA(_generic()));
    });

    test('con un conteo como texto', () async {
      final body = contractBody();
      statesOf(body)['AGENDADA'] = '40';
      final (repository, _) = _repository(200, body);
      await expectLater(repository.statistics(), throwsA(_generic()));
    });

    test('con una fecha mal formada', () async {
      final body = contractBody()..['desde'] = '2026-13-45';
      final (repository, _) = _repository(200, body);
      await expectLater(repository.statistics(), throwsA(_generic()));
    });
  });

  group('errores del servidor', () {
    test('400 VALIDACION es validation y conserva el mensaje', () async {
      final (repository, _) = _repository(400, {
        'code': 'VALIDACION',
        'message': 'desde no puede ser posterior a hasta',
      });
      await expectLater(
        repository.statistics(),
        throwsA(
          _failure(AppointmentStatisticsFailure.validation).having(
            (e) => e.message,
            'message',
            'desde no puede ser posterior a hasta',
          ),
        ),
      );
    });

    test('401 NO_AUTENTICADO es unauthenticated', () async {
      final (repository, _) = _repository(401, {
        'code': 'NO_AUTENTICADO',
        'message': 'Sesión vencida',
      });
      await expectLater(
        repository.statistics(),
        throwsA(_failure(AppointmentStatisticsFailure.unauthenticated)),
      );
    });

    test('403 ACCESO_DENEGADO es forbidden', () async {
      final (repository, _) = _repository(403, {
        'code': 'ACCESO_DENEGADO',
        'message': 'Sin permiso',
      });
      await expectLater(
        repository.statistics(),
        throwsA(_failure(AppointmentStatisticsFailure.forbidden)),
      );
    });

    test('500 con otro code es other', () async {
      final (repository, _) = _repository(500, {
        'code': 'ERROR_INTERNO',
        'message': 'Falló algo',
      });
      await expectLater(
        repository.statistics(),
        throwsA(_failure(AppointmentStatisticsFailure.other)),
      );
    });
  });
}
