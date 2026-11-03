import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/estadisticas/turnos/repositories/api_shift_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/turnos/repositories/shift_statistics_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shift_statistics_fixtures.dart';

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

(ApiShiftStatisticsRepository, _Adapter) _repository(int status, Object? body) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiShiftStatisticsRepository(dio), adapter);
}

TypeMatcher<ShiftStatisticsException> _failure(
  ShiftStatisticsFailure failure,
) => isA<ShiftStatisticsException>().having(
  (e) => e.failure,
  'failure',
  failure,
);

/// El error genérico: un `ApiException` común, no uno de los casos que la
/// pantalla distingue.
Matcher _generic() => isA<ApiException>()
    .having((e) => e.message, 'message', kApiGenericMessage)
    .having(
      (e) => e is ShiftStatisticsException,
      'es ShiftStatisticsException',
      isFalse,
    );

void main() {
  test('sin parámetros pide la ruta sin query y parsea la respuesta', () async {
    final (repository, adapter) = _repository(200, contractBody());

    final result = await repository.utilization();

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/estadisticas/turnos');
    expect(adapter.last!.queryParameters, isEmpty);
    expect(result.from, DateTime.utc(2026, 10, 1));
    expect(result.to, DateTime.utc(2026, 10, 31));
    expect(result.items, hasLength(2));
    expect(result.items[0].doctor.fullName, 'Marta Rodríguez');
    expect(result.items[0].percentage, 75.0);
    expect(result.items[1].percentage, isNull);
  });

  test('con las dos fechas manda desde y hasta como YYYY-MM-DD', () async {
    final (repository, adapter) = _repository(200, contractBody());

    await repository.utilization(
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

    await repository.utilization(from: DateTime.utc(2026, 10, 5));

    expect(adapter.last!.queryParameters, {'desde': '2026-10-05'});
  });

  test('con solo hasta manda solo hasta', () async {
    final (repository, adapter) = _repository(200, contractBody());

    await repository.utilization(to: DateTime.utc(2026, 10, 20));

    expect(adapter.last!.queryParameters, {'hasta': '2026-10-20'});
  });

  test('un porcentaje entero en la respuesta no es un error', () async {
    final body = contractBody();
    firstItem(body)['porcentajeUtilizacion'] = 100;
    final (repository, _) = _repository(200, body);

    final result = await repository.utilization();

    expect(result.items.first.percentage, 100.0);
  });

  group('una respuesta inválida da el error genérico', () {
    test('sin items', () async {
      final body = contractBody()..remove('items');
      final (repository, _) = _repository(200, body);
      await expectLater(repository.utilization(), throwsA(_generic()));
    });

    test('con numerosOcupados como texto', () async {
      final body = contractBody();
      firstItem(body)['numerosOcupados'] = '9';
      final (repository, _) = _repository(200, body);
      await expectLater(repository.utilization(), throwsA(_generic()));
    });

    test('con un ítem sin medico', () async {
      final body = contractBody();
      firstItem(body).remove('medico');
      final (repository, _) = _repository(200, body);
      await expectLater(repository.utilization(), throwsA(_generic()));
    });

    for (final weekday in [0, 8]) {
      test('con diaSemana $weekday', () async {
        final body = contractBody();
        firstItem(body)['diaSemana'] = weekday;
        final (repository, _) = _repository(200, body);
        await expectLater(repository.utilization(), throwsA(_generic()));
      });
    }

    test('con una fecha mal formada', () async {
      final body = contractBody()..['hasta'] = '31-10-2026';
      final (repository, _) = _repository(200, body);
      await expectLater(repository.utilization(), throwsA(_generic()));
    });
  });

  group('errores del servidor', () {
    test('400 VALIDACION es validation y conserva el mensaje', () async {
      final (repository, _) = _repository(400, {
        'code': 'VALIDACION',
        'message': 'desde no puede ser posterior a hasta',
      });
      await expectLater(
        repository.utilization(),
        throwsA(
          _failure(ShiftStatisticsFailure.validation).having(
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
        repository.utilization(),
        throwsA(_failure(ShiftStatisticsFailure.unauthenticated)),
      );
    });

    test('403 ACCESO_DENEGADO es forbidden', () async {
      final (repository, _) = _repository(403, {
        'code': 'ACCESO_DENEGADO',
        'message': 'Sin permiso',
      });
      await expectLater(
        repository.utilization(),
        throwsA(_failure(ShiftStatisticsFailure.forbidden)),
      );
    });

    test('500 con otro code es other', () async {
      final (repository, _) = _repository(500, {
        'code': 'ERROR_INTERNO',
        'message': 'Falló algo',
      });
      await expectLater(
        repository.utilization(),
        throwsA(_failure(ShiftStatisticsFailure.other)),
      );
    });
  });
}
