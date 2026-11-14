import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/notificaciones/models/notification_query.dart';
import 'package:agenda_medica/features/notificaciones/repositories/api_notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/repositories/notification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _notification({
  int id = 15001,
  String type = 'SUSPENSION',
  String title = 'Turno suspendido',
  int consultaId = 9001,
  String content = 'Se suspendió el turno del 20/10/2026.',
  String createdAt = '2026-10-16T11:20:00-03:00',
}) => {
  'id': id,
  'tipo': type,
  'titulo': title,
  'consultaId': consultaId,
  'contenido': content,
  'creadaEn': createdAt,
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

(ApiNotificationRepository, _Adapter) _repository(int status, Object? body) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiNotificationRepository(dio), adapter);
}

void main() {
  test('pide la lista por la ruta centralizada con page y size y parsea la '
      'página', () async {
    final (repository, adapter) = _repository(200, {
      'items': [
        _notification(),
        _notification(
          id: 15000,
          type: 'AGENDA',
          title: 'Consulta agendada',
          consultaId: 9002,
          content: 'Tu consulta quedó agendada.',
          createdAt: '2026-10-14T10:12:45-03:00',
        ),
      ],
      'page': 1,
      'size': 10,
      'total': 23,
    });

    final result = await repository.list(
      const NotificationQuery(page: 1, size: 10),
    );

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/notificaciones');
    expect(adapter.last!.queryParameters, {'page': 1, 'size': 10});
    expect(result.page, 1);
    expect(result.size, 10);
    expect(result.total, 23);
    expect(result.hasPrevious, isTrue);
    expect(result.hasNext, isTrue);
    expect(result.items, hasLength(2));
    final first = result.items.first;
    expect(first.id, 15001);
    expect(first.type, 'SUSPENSION');
    expect(first.title, 'Turno suspendido');
    expect(first.consultaId, 9001);
    expect(first.content, 'Se suspendió el turno del 20/10/2026.');
    expect(first.createdAt, DateTime.utc(2026, 10, 16, 14, 20));
    expect(result.items.last.id, 15000);
    expect(result.items.last.type, 'AGENDA');
  });

  test('sin parámetros pide la página 0 de 20', () async {
    final (repository, adapter) = _repository(200, {
      'items': <Object>[],
      'page': 0,
      'size': 20,
      'total': 0,
    });

    await repository.list(const NotificationQuery());

    expect(adapter.last!.queryParameters, {'page': 0, 'size': 20});
  });

  test('una página vacía no tiene anterior ni siguiente', () async {
    final (repository, _) = _repository(200, {
      'items': <Object>[],
      'page': 0,
      'size': 20,
      'total': 0,
    });

    final result = await repository.list(const NotificationQuery());

    expect(result.items, isEmpty);
    expect(result.total, 0);
    expect(result.hasPrevious, isFalse);
    expect(result.hasNext, isFalse);
  });

  test('la última página no tiene siguiente', () async {
    final (repository, _) = _repository(200, {
      'items': [_notification()],
      'page': 2,
      'size': 10,
      'total': 21,
    });

    final result = await repository.list(
      const NotificationQuery(page: 2, size: 10),
    );

    expect(result.hasPrevious, isTrue);
    expect(result.hasNext, isFalse);
  });

  for (final (status, code, failure) in [
    (400, 'VALIDACION', NotificationFailure.other),
    (401, 'NO_AUTENTICADO', NotificationFailure.unauthenticated),
    (403, 'ACCESO_DENEGADO', NotificationFailure.forbidden),
  ]) {
    test('mapea $status/$code', () async {
      final (repository, _) = _repository(status, {
        'code': code,
        'message': 'respuesta contractual',
      });

      await expectLater(
        repository.list(const NotificationQuery()),
        throwsA(
          isA<NotificationException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.message, 'message', 'respuesta contractual'),
        ),
      );
    });
  }

  test('un código desconocido con otro estado es la falla genérica', () async {
    final (repository, _) = _repository(500, {
      'code': 'ERROR_INTERNO',
      'message': 'Algo falló.',
    });

    await expectLater(
      repository.list(const NotificationQuery()),
      throwsA(
        isA<NotificationException>().having(
          (e) => e.failure,
          'failure',
          NotificationFailure.other,
        ),
      ),
    );
  });

  test('un item con un campo de otro tipo es el error genérico', () async {
    final (repository, _) = _repository(200, {
      'items': [
        {'id': 'incorrecto'},
      ],
      'page': 0,
      'size': 20,
      'total': 1,
    });

    await expectLater(
      repository.list(const NotificationQuery()),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', kApiGenericMessage)
            .having((e) => e is NotificationException, 'es falla', isFalse),
      ),
    );
  });

  test('una fecha de creación que no es ISO es el error genérico', () async {
    final (repository, _) = _repository(200, {
      'items': [_notification(createdAt: '16/10/2026')],
      'page': 0,
      'size': 20,
      'total': 1,
    });

    await expectLater(
      repository.list(const NotificationQuery()),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          kApiGenericMessage,
        ),
      ),
    );
  });

  test('una respuesta sin cuerpo de página es el error genérico', () async {
    final (repository, _) = _repository(200, {'items': 'no es una lista'});

    await expectLater(
      repository.list(const NotificationQuery()),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          kApiGenericMessage,
        ),
      ),
    );
  });
}
