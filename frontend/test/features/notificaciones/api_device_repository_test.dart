import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/notificaciones/repositories/api_device_repository.dart';
import 'package:agenda_medica/features/notificaciones/repositories/device_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object? body;
  RequestOptions? last;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    calls++;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiDeviceRepository, _Adapter) _repo(int status, Object? body) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiDeviceRepository(dio), adapter);
}

const _created = {
  'id': 61,
  'habilitado': true,
  'registradoEn': '2026-10-14T10:20:00-03:00',
};

TypeMatcher<DeviceException> _failure(DeviceFailure failure) =>
    isA<DeviceException>().having((e) => e.failure, 'failure', failure);

void main() {
  group('register', () {
    test('201 es un dispositivo nuevo y manda el token en el cuerpo', () async {
      final (repo, adapter) = _repo(201, _created);

      final result = await repo.register('fcm-token-1');

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/dispositivos');
      expect(adapter.last!.data, {'token': 'fcm-token-1'});
      expect(result.created, isTrue);
      expect(result.id, 61);
      expect(result.enabled, isTrue);
      expect(result.registeredAt, DateTime.utc(2026, 10, 14, 13, 20));
    });

    test('200 es un dispositivo que ya existía', () async {
      final (repo, _) = _repo(200, _created);

      final result = await repo.register('fcm-token-1');

      expect(result.created, isFalse);
      expect(result.id, 61);
      expect(result.enabled, isTrue);
    });

    test(
      'un token vacío o de solo espacios no envía ninguna petición',
      () async {
        for (final token in ['', '   ']) {
          final (repo, adapter) = _repo(201, _created);

          await expectLater(
            repo.register(token),
            throwsA(_failure(DeviceFailure.validation)),
          );
          expect(adapter.calls, 0);
        }
      },
    );

    test('una respuesta sin id es el error genérico', () async {
      final (repo, _) = _repo(201, {
        'habilitado': true,
        'registradoEn': '2026-10-14T10:20:00-03:00',
      });

      await expectLater(
        repo.register('fcm-token-1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            kApiGenericMessage,
          ),
        ),
      );
    });

    const cases = {
      (400, 'VALIDACION'): DeviceFailure.validation,
      (401, 'NO_AUTENTICADO'): DeviceFailure.unauthenticated,
      (403, 'ACCESO_DENEGADO'): DeviceFailure.forbidden,
      (500, 'ERROR_INTERNO'): DeviceFailure.other,
    };
    for (final entry in cases.entries) {
      final (status, code) = entry.key;
      test(
        '$status $code es ${entry.value.name} con el mensaje del servidor',
        () async {
          final (repo, _) = _repo(status, {
            'code': code,
            'message': 'Mensaje de prueba.',
          });

          await expectLater(
            repo.register('fcm-token-1'),
            throwsA(
              _failure(entry.value)
                  .having((e) => e.message, 'message', 'Mensaje de prueba.'),
            ),
          );
        },
      );
    }
  });

  group('deactivate', () {
    test('204 manda el token a la ruta de baja y no devuelve nada', () async {
      final (repo, adapter) = _repo(204, null);

      await repo.deactivate('fcm-token-1');

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/dispositivos/baja');
      expect(adapter.last!.data, {'token': 'fcm-token-1'});
    });

    test(
      'un token vacío o de solo espacios no envía ninguna petición',
      () async {
        for (final token in ['', '   ']) {
          final (repo, adapter) = _repo(204, null);

          await expectLater(
            repo.deactivate(token),
            throwsA(_failure(DeviceFailure.validation)),
          );
          expect(adapter.calls, 0);
        }
      },
    );

    test(
      'un 400 VALIDACION es validation con el mensaje del servidor',
      () async {
        final (repo, _) = _repo(400, {
          'code': 'VALIDACION',
          'message': 'Falta el identificador.',
        });

        await expectLater(
          repo.deactivate('fcm-token-1'),
          throwsA(
            _failure(DeviceFailure.validation)
                .having((e) => e.message, 'message', 'Falta el identificador.'),
          ),
        );
      },
    );

    test('un 401 sin code reconocido es unauthenticated', () async {
      final (repo, _) = _repo(401, {'code': 'OTRO', 'message': 'x'});

      await expectLater(
        repo.deactivate('fcm-token-1'),
        throwsA(_failure(DeviceFailure.unauthenticated)),
      );
    });
  });
}
