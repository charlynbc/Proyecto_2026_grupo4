import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/repositories/api_specialty_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/repositories/specialty_statistics_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _contractBody() => {
  'desde': '2026-10-01',
  'hasta': '2026-10-31',
  'items': <Map<String, dynamic>>[
    {
      'especialidad': {
        'id': 1,
        'nombre': 'Medicina General',
        'requierePase': false,
      },
      'cantidadConsultas': 128,
    },
    {
      'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
      'cantidadConsultas': 42,
    },
  ],
};

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

(ApiSpecialtyStatisticsRepository, _Adapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiSpecialtyStatisticsRepository(dio), adapter);
}

TypeMatcher<SpecialtyStatisticsException> _failure(
  SpecialtyStatisticsFailure failure,
) => isA<SpecialtyStatisticsException>().having(
  (e) => e.failure,
  'failure',
  failure,
);

/// El error genérico: un `ApiException` común, no uno de los casos que la
/// pantalla distingue.
Matcher _generic() => isA<ApiException>()
    .having((e) => e.message, 'message', kApiGenericMessage)
    .having(
      (e) => e is SpecialtyStatisticsException,
      'es SpecialtyStatisticsException',
      isFalse,
    );

void main() {
  test('sin parámetros pide la ruta sin query y parsea la respuesta', () async {
    final (repository, adapter) = _repository(200, _contractBody());

    final demand = await repository.demand();

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/estadisticas/especialidades');
    expect(adapter.last!.queryParameters, isEmpty);
    expect(demand.from, DateTime.utc(2026, 10, 1));
    expect(demand.to, DateTime.utc(2026, 10, 31));
    expect(demand.items, hasLength(2));
    expect(demand.items[0].specialty.name, 'Medicina General');
    expect(demand.items[0].count, 128);
    expect(demand.items[1].specialty.requiresReferral, isTrue);
  });

  test('con las dos fechas manda desde y hasta como YYYY-MM-DD', () async {
    final (repository, adapter) = _repository(200, _contractBody());

    await repository.demand(
      from: DateTime.utc(2026, 10, 5),
      to: DateTime.utc(2026, 10, 20),
    );

    expect(adapter.last!.queryParameters, {
      'desde': '2026-10-05',
      'hasta': '2026-10-20',
    });
  });

  test('con solo desde manda solo desde', () async {
    final (repository, adapter) = _repository(200, _contractBody());

    await repository.demand(from: DateTime.utc(2026, 10, 5));

    expect(adapter.last!.queryParameters, {'desde': '2026-10-05'});
  });

  test('con solo hasta manda solo hasta', () async {
    final (repository, adapter) = _repository(200, _contractBody());

    await repository.demand(to: DateTime.utc(2026, 10, 20));

    expect(adapter.last!.queryParameters, {'hasta': '2026-10-20'});
  });

  group('una respuesta inválida da el error genérico', () {
    test('sin items', () async {
      final body = _contractBody()..remove('items');
      final (repository, _) = _repository(200, body);
      await expectLater(repository.demand(), throwsA(_generic()));
    });

    test('con cantidadConsultas como texto', () async {
      final body = _contractBody();
      (body['items'] as List<Map<String, dynamic>>)[0]['cantidadConsultas'] =
          '128';
      final (repository, _) = _repository(200, body);
      await expectLater(repository.demand(), throwsA(_generic()));
    });

    test('con una fecha mal formada', () async {
      final body = _contractBody()..['hasta'] = '31-10-2026';
      final (repository, _) = _repository(200, body);
      await expectLater(repository.demand(), throwsA(_generic()));
    });
  });

  group('errores del servidor', () {
    test('400 VALIDACION es validation y conserva el mensaje', () async {
      final (repository, _) = _repository(400, {
        'code': 'VALIDACION',
        'message': 'desde no puede ser posterior a hasta',
      });
      await expectLater(
        repository.demand(),
        throwsA(
          _failure(SpecialtyStatisticsFailure.validation).having(
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
        repository.demand(),
        throwsA(_failure(SpecialtyStatisticsFailure.unauthenticated)),
      );
    });

    test('403 ACCESO_DENEGADO es forbidden', () async {
      final (repository, _) = _repository(403, {
        'code': 'ACCESO_DENEGADO',
        'message': 'Sin permiso',
      });
      await expectLater(
        repository.demand(),
        throwsA(_failure(SpecialtyStatisticsFailure.forbidden)),
      );
    });

    test('500 con otro code es other', () async {
      final (repository, _) = _repository(500, {
        'code': 'ERROR_INTERNO',
        'message': 'Falló algo',
      });
      await expectLater(
        repository.demand(),
        throwsA(_failure(SpecialtyStatisticsFailure.other)),
      );
    });
  });
}
