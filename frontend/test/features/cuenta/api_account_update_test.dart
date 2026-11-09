import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/cuenta/models/account_changes.dart';
import 'package:agenda_medica/features/cuenta/repositories/account_repository.dart';
import 'package:agenda_medica/features/cuenta/repositories/api_account_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.response);

  final int status;
  final Object? response;
  RequestOptions? request;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    body = jsonDecode(await utf8.decoder.bind(requestStream!).join());
    return ResponseBody.fromString(
      jsonEncode(response),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiAccountRepository _repo(_Adapter adapter) =>
    ApiAccountRepository(Dio()..httpClientAdapter = adapter);

void main() {
  test('manda PATCH a la cuenta propia y lee la respuesta', () async {
    final adapter = _Adapter(200, {
      ...luciaJson(pendingEmail: 'nuevo@example.org'),
      'direccion': 'Av. Italia 1234',
      'telefono1': '099000111',
    });
    final account = await _repo(adapter).update(
      const AccountChanges(
        address: 'Av. Italia 1234',
        phone1: '099000111',
        email: 'nuevo@example.org',
      ),
    );

    expect(adapter.request!.method, 'PATCH');
    expect(adapter.request!.path, '/api/cuentas/me');
    expect(adapter.request!.queryParameters, isEmpty);
    expect(adapter.body, {
      'direccion': 'Av. Italia 1234',
      'telefono1': '099000111',
      'correo': 'nuevo@example.org',
    });
    expect(account.address, 'Av. Italia 1234');
    expect(account.phone1, '099000111');
    expect(account.pendingEmail, 'nuevo@example.org');
    expect(account.email, 'lucia@example.org');
  });

  test('envía el segundo teléfono explícitamente nulo al borrarlo', () async {
    final adapter = _Adapter(200, luciaJson());
    await _repo(adapter).update(const AccountChanges(phone2: (value: null)));
    expect(adapter.body, {'telefono2': null});
  });

  test('sin cambios no se hace un PATCH', () async {
    final adapter = _Adapter(200, luciaJson());
    await expectLater(
      _repo(adapter).update(const AccountChanges()),
      throwsA(isA<AccountValidationException>()),
    );
    expect(adapter.request, isNull);
  });

  test('400 VALIDACION conserva el mensaje del servidor', () async {
    final adapter = _Adapter(400, {
      'code': 'VALIDACION',
      'message': 'La dirección no puede quedar vacía',
    });
    await expectLater(
      _repo(adapter).update(const AccountChanges(address: '')),
      throwsA(
        isA<AccountValidationException>().having(
          (error) => error.message,
          'message',
          'La dirección no puede quedar vacía',
        ),
      ),
    );
  });

  test('500 sin mensaje se convierte al error genérico', () async {
    final adapter = _Adapter(500, null);
    await expectLater(
      _repo(adapter).update(const AccountChanges(address: 'Av. Italia 1234')),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          kApiGenericMessage,
        ),
      ),
    );
  });
}
