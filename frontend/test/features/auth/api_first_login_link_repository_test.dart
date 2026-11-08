import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/auth/repositories/api_first_login_link_repository.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/first_login_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde con un estado y un cuerpo fijos (o sin cuerpo, o sin respuesta) y
/// recuerda el último pedido.
class _Adapter implements HttpClientAdapter {
  _Adapter.json(this.status, Map<String, dynamic> body)
    : raw = jsonEncode(body),
      withoutResponse = false;

  _Adapter.empty(this.status) : raw = '', withoutResponse = false;

  _Adapter.withoutResponse() : status = 0, raw = '', withoutResponse = true;

  final int status;
  final String raw;
  final bool withoutResponse;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (withoutResponse) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin red',
      );
    }
    return ResponseBody.fromString(
      raw,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiFirstLoginLinkRepository _repo(_Adapter adapter) =>
    ApiFirstLoginLinkRepository(Dio()..httpClientAdapter = adapter);

Future<void> _validate(ApiFirstLoginLinkRepository repo) =>
    repo.validateLink(token: 'abc123');

void main() {
  test(
    'hace POST a la ruta de validar con el token solo en el cuerpo',
    () async {
      final adapter = _Adapter.empty(200);

      await _validate(_repo(adapter));

      final sent = adapter.last!;
      expect(sent.method, 'POST');
      expect(sent.path, '/api/auth/primer-ingreso/validar');
      expect(sent.data, {'token': 'abc123'});
      expect(sent.queryParameters, isEmpty);
      expect(sent.uri.toString(), isNot(contains('abc123')));
    },
  );

  test('no manda el header Authorization', () async {
    final adapter = _Adapter.empty(200);

    await _validate(_repo(adapter));

    expect(adapter.last!.headers.containsKey('Authorization'), isFalse);
  });

  test('200 sin cuerpo termina sin error', () async {
    await expectLater(_validate(_repo(_Adapter.empty(200))), completes);
  });

  test('400 ENLACE_INVALIDO da InvalidActivationLinkException con el '
      'mensaje del contrato', () {
    final repo = _repo(
      _Adapter.json(400, {
        'code': 'ENLACE_INVALIDO',
        'message':
            'El enlace ya no es válido. Pedí uno nuevo desde la pantalla de '
            'ingreso.',
      }),
    );

    expect(
      _validate(repo),
      throwsA(
        isA<InvalidActivationLinkException>().having(
          (e) => e.message,
          'message',
          'El enlace ya no es válido. Pedí uno nuevo desde la pantalla de '
              'ingreso.',
        ),
      ),
    );
  });

  test(
    'ENLACE_INVALIDO conserva el mensaje distintivo del servidor al validar',
    () async {
      final repo = _repo(
        _Adapter.json(400, {
          'code': 'ENLACE_INVALIDO',
          'message':
              'No podemos aceptar este enlace de activación. Solicitá otro.',
        }),
      );

      await expectLater(
        _validate(repo),
        throwsA(
          isA<InvalidActivationLinkException>().having(
            (error) => error.message,
            'message',
            'No podemos aceptar este enlace de activación. Solicitá otro.',
          ),
        ),
      );
    },
  );

  for (final body in <Map<String, dynamic>>[
    {'code': 'ENLACE_INVALIDO'},
    {'code': 'ENLACE_INVALIDO', 'message': ''},
  ]) {
    test(
      'validar conserva fallback con mensaje ${body.containsKey('message') ? 'vacío' : 'ausente'}',
      () async {
        await expectLater(
          _validate(_repo(_Adapter.json(400, body))),
          throwsA(
            isA<InvalidActivationLinkException>().having(
              (error) => error.message,
              'message',
              'El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.',
            ),
          ),
        );
      },
    );
  }

  group('cualquier otro resultado no es un enlace inválido', () {
    final cases = <String, _Adapter>{
      '500': _Adapter.json(500, {
        'code': 'ERROR_INTERNO',
        'message': 'Ocurrió un problema de nuestro lado.',
      }),
      '401 sin cuerpo': _Adapter.empty(401),
      'sin conexión': _Adapter.withoutResponse(),
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(
          _validate(_repo(entry.value)),
          throwsA(
            allOf(
              isA<AuthException>(),
              isNot(isA<InvalidActivationLinkException>()),
            ),
          ),
        );
      });
    }
  });
}
