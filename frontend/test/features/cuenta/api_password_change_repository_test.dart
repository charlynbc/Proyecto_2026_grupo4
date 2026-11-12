import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/cuenta/repositories/api_password_change_repository.dart';
import 'package:agenda_medica/features/cuenta/repositories/password_change_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _OfflineAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => throw const SocketException('sin conexión');

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<void> change(ApiPasswordChangeRepository repository) => repository
      .change(currentPassword: 'claveSegura1', newPassword: 'claveNueva9');

  test(
    'envía solo las dos claves al endpoint y acepta 204 sin cuerpo',
    () async {
      final adapter = _Adapter(204, {});
      await change(
        ApiPasswordChangeRepository(Dio()..httpClientAdapter = adapter),
      );
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/auth/cambiar-contrasena');
      expect(adapter.last!.data, {
        'passwordActual': 'claveSegura1',
        'passwordNueva': 'claveNueva9',
      });
    },
  );

  for (final (code, failure, message) in [
    (
      'CONTRASENA_ACTUAL_INCORRECTA',
      PasswordChangeFailure.wrongCurrentPassword,
      'La contraseña actual no es correcta.',
    ),
    ('VALIDACION', PasswordChangeFailure.validation, 'Revisá la nueva clave.'),
  ]) {
    test('traduce $code y conserva el mensaje del servidor', () async {
      final adapter = _Adapter(400, {'code': code, 'message': message});
      final repository = ApiPasswordChangeRepository(
        Dio()..httpClientAdapter = adapter,
      );
      await expectLater(
        change(repository),
        throwsA(
          isA<PasswordChangeException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.message, 'message', message),
        ),
      );
    });
  }

  test('500 sin mensaje usa el mensaje genérico', () async {
    final repository = ApiPasswordChangeRepository(
      Dio()..httpClientAdapter = _Adapter(500, {}),
    );
    await expectLater(
      change(repository),
      throwsA(
        isA<PasswordChangeException>()
            .having((e) => e.failure, 'failure', PasswordChangeFailure.other)
            .having((e) => e.message, 'message', kApiGenericMessage),
      ),
    );
  });

  test('sin respuesta informa un error de conexión', () async {
    final repository = ApiPasswordChangeRepository(
      Dio()..httpClientAdapter = _OfflineAdapter(),
    );
    await expectLater(
      change(repository),
      throwsA(
        isA<PasswordChangeException>()
            .having((e) => e.failure, 'failure', PasswordChangeFailure.other)
            .having((e) => e.message, 'message', kApiNoConnectionMessage),
      ),
    );
  });
}
