import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/repositories/api_schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/schedule_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'schedule_entry_test.dart' show entryJson;

/// Adaptador de dio que anota el pedido y responde con lo indicado, sin red.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter.json(this.status, this.body) : raw = null, noConnection = false;

  /// Una respuesta que no es JSON (por ejemplo, la página de error de un
  /// proxy).
  _StubAdapter.raw(this.status, this.raw) : body = null, noConnection = false;

  /// Sin conexión: el pedido ni llega al servidor.
  _StubAdapter.offline()
    : status = 0,
      body = null,
      raw = null,
      noConnection = true;

  final int status;
  final Object? body;
  final String? raw;
  final bool noConnection;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (noConnection) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final isRaw = raw != null;
    return ResponseBody.fromString(
      isRaw ? raw! : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          isRaw ? 'text/html' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiScheduleRepository, _StubAdapter) _repository(_StubAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiScheduleRepository(dio), adapter);
}

(ApiScheduleRepository, _StubAdapter) _ok(Object? body) =>
    _repository(_StubAdapter.json(200, body));

(ApiScheduleRepository, _StubAdapter) _fails(
  int status,
  String code,
  String message,
) => _repository(_StubAdapter.json(status, {'code': code, 'message': message}));

ScheduleFilters _today() => ScheduleFilters(date: DateTime.utc(2026, 10, 26));

Map<String, dynamic> _page(List<Object?> items, {int total = 2}) => {
  'items': items,
  'page': 0,
  'size': 20,
  'total': total,
};

/// Una respuesta mal formada se vuelve el error genérico, con su mensaje.
Matcher get _genericError => isA<ApiException>()
    .having((e) => e.runtimeType, 'es un ApiException liso', ApiException)
    .having((e) => e.message, 'message', kApiGenericMessage);

void main() {
  group('search (#28)', () {
    test('pide GET /api/agendas', () async {
      final (repository, adapter) = _ok(_page([]));

      await repository.search(_today());

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/agendas');
    });

    test('sin filtros manda solo fecha, orden, sentido, page y size', () async {
      final (repository, adapter) = _ok(_page([]));

      await repository.search(_today());

      expect(adapter.last!.queryParameters, {
        'fecha': '2026-10-26',
        'orden': 'fechaHora',
        'sentido': 'asc',
        'page': 0,
        'size': 20,
      });
    });

    test('con filtros manda los parámetros exactos', () async {
      final (repository, adapter) = _ok(_page([]));

      await repository.search(
        ScheduleFilters(
          date: DateTime.utc(2026, 10, 26),
          ci: '9.000.004-6',
          appointmentId: '15',
          doctorId: 17,
          status: 'AGENDADA',
          arrived: false,
          order: ScheduleOrder.arrivalTime,
          ascending: false,
          page: 1,
        ),
      );

      expect(adapter.last!.queryParameters, {
        'ci': '90000046',
        'consultaId': 15,
        'medicoId': 17,
        'fecha': '2026-10-26',
        'estado': 'AGENDADA',
        'llegada': false,
        'orden': 'horaLlegada',
        'sentido': 'desc',
        'page': 1,
        'size': 20,
      });
    });

    test('lee items, page, size y total', () async {
      final (repository, _) = _ok({
        'items': [
          entryJson(),
          entryJson(arrivedAt: null, status: 'NO_ASISTIO'),
        ],
        'page': 1,
        'size': 2,
        'total': 5,
      });

      final result = await repository.search(_today());

      expect(result.items, hasLength(2));
      expect(result.page, 1);
      expect(result.size, 2);
      expect(result.total, 5);
      expect(result.items[0].appointmentId, 9001);
      expect(result.items[0].status, 'AGENDADA');
      expect(result.items[1].status, 'NO_ASISTIO');
    });

    test('un item con llegadaEn y otro sin llegadaEn', () async {
      final (repository, _) = _ok(
        _page([
          entryJson(arrivedAt: '2026-10-22T08:35:00-03:00'),
          entryJson(arrivedAt: null),
        ]),
      );

      final result = await repository.search(_today());

      expect(result.items[0].arrivalTime, '08:35');
      expect(result.items[1].arrivedAt, isNull);
      expect(result.items[1].arrivalTime, isNull);
    });

    test('una página sin consultas es una lista vacía', () async {
      final (repository, _) = _ok(_page([], total: 0));

      final result = await repository.search(_today());

      expect(result.items, isEmpty);
      expect(result.total, 0);
    });
  });

  group('respuestas mal formadas', () {
    test('un estado desconocido da el error genérico', () async {
      final (repository, _) = _ok(_page([entryJson(status: 'PENDIENTE')]));

      await expectLater(repository.search(_today()), throwsA(_genericError));
    });

    test('un campo obligatorio faltante da el error genérico', () async {
      final item = entryJson()..remove('socio');
      final (repository, _) = _ok(_page([item]));

      await expectLater(repository.search(_today()), throwsA(_genericError));
    });

    test('una llegada sin zona horaria da el error genérico', () async {
      final (repository, _) = _ok(
        _page([entryJson(arrivedAt: '2026-10-22T08:35:00')]),
      );

      await expectLater(repository.search(_today()), throwsA(_genericError));
    });

    test('una página sin items da el error genérico', () async {
      final (repository, _) = _ok({'page': 0, 'size': 20, 'total': 0});

      await expectLater(repository.search(_today()), throwsA(_genericError));
    });

    test('un cuerpo vacío da el error genérico', () async {
      final (repository, _) = _ok(null);

      await expectLater(repository.search(_today()), throwsA(_genericError));
    });
  });

  group('errores', () {
    test('400 VALIDACION llega como error de validación con el texto del '
        'servidor', () async {
      final (repository, _) = _fails(
        400,
        'VALIDACION',
        'ci debe ser una cedula valida',
      );

      await expectLater(
        repository.search(_today()),
        throwsA(
          isA<ScheduleValidationException>()
              .having(
                (e) => e.message,
                'message',
                'ci debe ser una cedula valida',
              )
              .having((e) => e.code, 'code', 'VALIDACION'),
        ),
      );
    });

    test('se distingue por code, no por el texto del mensaje', () async {
      final (repository, _) = _fails(400, 'OTRO_CODIGO', 'VALIDACION');

      await expectLater(
        repository.search(_today()),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e is ScheduleValidationException,
                'es de validación',
                isFalse,
              )
              .having((e) => e.message, 'message', 'VALIDACION'),
        ),
      );
    });

    test('un error del servidor conserva su mensaje', () async {
      final (repository, _) = _fails(500, 'ERROR_INTERNO', 'Fallo interno');

      await expectLater(
        repository.search(_today()),
        throwsA(
          isA<ApiException>()
              .having(
                (e) => e is ScheduleValidationException,
                'validación',
                isFalse,
              )
              .having((e) => e.message, 'message', 'Fallo interno'),
        ),
      );
    });

    test('un error sin cuerpo útil da el mensaje genérico', () async {
      final (repository, _) = _repository(_StubAdapter.raw(502, '<html>'));

      await expectLater(repository.search(_today()), throwsA(_genericError));
    });

    test('sin conexión da el mensaje de conexión', () async {
      final (repository, _) = _repository(_StubAdapter.offline());

      await expectLater(
        repository.search(_today()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            kApiNoConnectionMessage,
          ),
        ),
      );
    });
  });
}
