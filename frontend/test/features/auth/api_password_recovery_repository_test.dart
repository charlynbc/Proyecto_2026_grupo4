import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/repositories/api_password_recovery_repository.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_repository.dart';
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

ApiPasswordRecoveryRepository _repo(_Adapter adapter) =>
    ApiPasswordRecoveryRepository(Dio()..httpClientAdapter = adapter);

Future<void> _complete(ApiPasswordRecoveryRepository repo) => repo.complete(
  token: 'b7f3c1d0a9e84f2c8b1d6e5f4a3b2c1d',
  password: 'claveNueva9',
);

void main() {
  group('pedir el enlace (fila 48)', () {
    test('manda la cédula y el acceso SOCIO a la ruta del backend', () async {
      final adapter = _Adapter(202, {
        'message':
            'Si su cédula se encuentra registrada, se le ha enviado un correo '
            'electrónico con las instrucciones.',
      });

      await _repo(adapter)
          .requestLink(ci: '45678911', access: AccessType.socio);

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/auth/recuperacion/solicitar');
      expect(adapter.last!.data, {'ci': '45678911', 'acceso': 'SOCIO'});
    });

    test('con el acceso de empleados manda EMPLEADO', () async {
      final adapter = _Adapter(202, {'message': 'ok'});

      await _repo(adapter)
          .requestLink(ci: '45678911', access: AccessType.empleado);

      expect(adapter.last!.data, {'ci': '45678911', 'acceso': 'EMPLEADO'});
    });

    test('400 VALIDACION llega como AuthException con el mensaje del '
        'servidor', () {
      final repo = _repo(
        _Adapter(400, {
          'code': 'VALIDACION',
          'message': 'acceso debe ser SOCIO o EMPLEADO',
        }),
      );

      expect(
        repo.requestLink(ci: '45678911', access: AccessType.socio),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'acceso debe ser SOCIO o EMPLEADO',
          ),
        ),
      );
    });
  });

  group('elegir la contraseña nueva (fila 49)', () {
    test(
      'manda exactamente el token y la contraseña; 200 termina bien',
      () async {
        final adapter = _Adapter(200, {
          'message': 'Tu contraseña se actualizó correctamente. Ya podés iniciar sesión.',
        });

        await _complete(_repo(adapter));

        expect(adapter.last!.method, 'POST');
        expect(adapter.last!.path, '/api/auth/recuperacion/completar');
        expect(adapter.last!.data, {
          'token': 'b7f3c1d0a9e84f2c8b1d6e5f4a3b2c1d',
          'password': 'claveNueva9',
        });
      },
    );

    test('400 ENLACE_INVALIDO da InvalidRecoveryLinkException con el mensaje '
        'del servidor', () {
      final repo = _repo(
        _Adapter(400, {
          'code': 'ENLACE_INVALIDO',
          'message': 'Mensaje del servidor para el enlace.',
        }),
      );

      expect(
        _complete(repo),
        throwsA(
          isA<InvalidRecoveryLinkException>().having(
            (e) => e.message,
            'message',
            'Mensaje del servidor para el enlace.',
          ),
        ),
      );
    });

    test(
      'completar usa fallback si el mensaje contiene solo espacios',
      () async {
        final repo = _repo(
          _Adapter(400, {'code': 'ENLACE_INVALIDO', 'message': '   '}),
        );

        await expectLater(
          _complete(repo),
          throwsA(
            isA<InvalidRecoveryLinkException>().having(
              (error) => error.message,
              'message',
              'El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.',
            ),
          ),
        );
      },
    );

    test('400 VALIDACION da AuthException con el mensaje del servidor', () {
      final repo = _repo(
        _Adapter(400, {
          'code': 'VALIDACION',
          'message': 'La contraseña debe tener entre 8 caracteres y 72 bytes',
        }),
      );

      expect(
        _complete(repo),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'La contraseña debe tener entre 8 caracteres y 72 bytes',
          ),
        ),
      );
    });

    test('500 sin message da la AuthException genérica', () {
      final repo = _repo(_Adapter(500, {'code': 'ERROR_INTERNO'}));

      expect(
        _complete(repo),
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
        _complete(repo),
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
  });
}
