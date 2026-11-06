import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/auth/repositories/api_email_change_repository.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/email_change_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde con un estado y un JSON fijos, o sin respuesta (sin red), y
/// recuerda el último pedido.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body) : withoutResponse = false;

  _Adapter.withoutResponse()
    : status = 0,
      body = const {},
      withoutResponse = true;

  final int status;
  final Map<String, dynamic> body;
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

ApiEmailChangeRepository _repo(_Adapter adapter) =>
    ApiEmailChangeRepository(Dio()..httpClientAdapter = adapter);

Future<void> _confirm(ApiEmailChangeRepository repo) =>
    repo.confirm(token: 'b7f3c1d0a9e84f2c8b1d6e5f4a3b2c1d');

void main() {
  test('manda exactamente el token a la ruta del backend; 200 termina '
      'bien', () async {
    final adapter = _Adapter(200, {
      'message': 'Tu correo se actualizó correctamente.',
    });

    await _confirm(_repo(adapter));

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/auth/cambio-correo/confirmar');
    expect(adapter.last!.data, {'token': 'b7f3c1d0a9e84f2c8b1d6e5f4a3b2c1d'});
  });

  test('400 ENLACE_INVALIDO da InvalidEmailChangeLinkException con el '
      'mensaje del servidor', () {
    final repo = _repo(
      _Adapter(400, {
        'code': 'ENLACE_INVALIDO',
        'message': 'Mensaje del servidor para el enlace.',
      }),
    );

    expect(
      _confirm(repo),
      throwsA(
        isA<InvalidEmailChangeLinkException>().having(
          (e) => e.message,
          'message',
          'Mensaje del servidor para el enlace.',
        ),
      ),
    );
  });

  test('400 VALIDACION da AuthException con el mensaje del servidor', () {
    final repo = _repo(
      _Adapter(400, {'code': 'VALIDACION', 'message': 'Falta el token.'}),
    );

    expect(
      _confirm(repo),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'Falta el token.',
        ),
      ),
    );
  });

  test('500 sin message da la AuthException genérica', () {
    final repo = _repo(_Adapter(500, {'code': 'ERROR_INTERNO'}));

    expect(
      _confirm(repo),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'No pudimos completar la operación. Intentá de nuevo en unos '
              'minutos.',
        ),
      ),
    );
  });

  test('sin respuesta da el mensaje de conexión', () {
    final repo = _repo(_Adapter.withoutResponse());

    expect(
      _confirm(repo),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'No pudimos conectarnos con el servidor. Revisá tu conexión a '
              'internet e intentá de nuevo.',
        ),
      ),
    );
  });
}
