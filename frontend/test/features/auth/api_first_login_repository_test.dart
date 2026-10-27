import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/repositories/api_first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/first_login_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde con un estado y un JSON fijos y recuerda el último pedido.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Map<String, dynamic> body;
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

ApiFirstLoginRepository _repo(_Adapter adapter) =>
    ApiFirstLoginRepository(Dio()..httpClientAdapter = adapter);

Future<AccessType> _activate(ApiFirstLoginRepository repo) => repo.activate(
  token: 'tok-123',
  address: 'Calle 1',
  phone1: '099123456',
  password: 'claveSegura1',
);

void main() {
  group('contrato HTTP del primer ingreso (RF-02)', () {
    test('solicitar envía ci y acceso a la ruta del backend', () async {
      final adapter = _Adapter(202, {'message': 'ok'});

      await _repo(
        adapter,
      ).requestLink(ci: '12345678', access: AccessType.empleado);

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/auth/primer-ingreso/solicitar');
      expect(adapter.last!.data, {'ci': '12345678', 'acceso': 'EMPLEADO'});
    });

    test('completar envía token, dirección, teléfonos y password', () async {
      final adapter = _Adapter(200, {'rol': 'SOCIO'});

      final access = await _activate(_repo(adapter));

      expect(adapter.last!.path, '/api/auth/primer-ingreso/completar');
      expect(adapter.last!.data, {
        'token': 'tok-123',
        'direccion': 'Calle 1',
        'telefono1': '099123456',
        'telefono2': null,
        'password': 'claveSegura1',
      });
      expect(access, AccessType.socio);
    });

    test('cualquier rol que no sea SOCIO ingresa por el acceso empleado', () async {
      for (final rol in ['MEDICO', 'FUNCIONARIO', 'ADMINISTRADOR']) {
        final access = await _activate(_repo(_Adapter(200, {'rol': rol})));
        expect(access, AccessType.empleado, reason: rol);
      }
    });

    test('ENLACE_INVALIDO (vencido, usado o cuenta inactiva) se distingue', () {
      final repo = _repo(
        _Adapter(400, {
          'code': 'ENLACE_INVALIDO',
          'message': 'El enlace ya no es válido.',
        }),
      );

      expect(
        _activate(repo),
        throwsA(isA<InvalidActivationLinkException>()),
      );
    });

    test('otro 400 llega como AuthException con el mensaje del servidor', () {
      final repo = _repo(
        _Adapter(400, {
          'code': 'VALIDACION',
          'message': 'Los datos de activacion no son validos',
        }),
      );

      expect(
        _activate(repo),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'Los datos de activacion no son validos',
          ),
        ),
      );
    });
  });
}
