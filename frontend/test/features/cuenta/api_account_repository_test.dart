import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/repositories/api_account_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body, {this.offline = false});

  final int status;
  final Object? body;
  final bool offline;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin conexión',
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

(ApiAccountRepository, _StubAdapter) _api(
  int status,
  Object? body, {
  bool offline = false,
}) {
  final adapter = _StubAdapter(status, body, offline: offline);
  return (ApiAccountRepository(Dio()..httpClientAdapter = adapter), adapter);
}

Matcher _apiMessage(String message) =>
    throwsA(isA<ApiException>().having((e) => e.message, 'message', message));

void main() {
  test('pide GET /api/cuentas/me sin parámetros y lee el contrato', () async {
    final (repo, adapter) = _api(200, luciaJson());

    final account = await repo.get();

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/cuentas/me');
    expect(adapter.last!.queryParameters, isEmpty);
    expect(account.ci, '45678911');
    expect(account.name, 'Lucía');
    expect(account.lastName, 'Fernández');
    expect(account.role, UserRole.socio);
    expect(account.address, 'Av. 18 de Julio 1234, Montevideo');
  });

  test('una respuesta que no es un objeto da el error genérico', () async {
    final (repo, _) = _api(200, ['no', 'es', 'un', 'objeto']);

    await expectLater(repo.get(), _apiMessage(kApiGenericMessage));
  });

  test('un rol desconocido en la respuesta da el error genérico', () async {
    final (repo, _) = _api(200, {...luciaJson(), 'rol': 'ENFERMERO'});

    await expectLater(repo.get(), _apiMessage(kApiGenericMessage));
  });

  test('un 500 sin mensaje da el error genérico', () async {
    final (repo, _) = _api(500, null);

    await expectLater(repo.get(), _apiMessage(kApiGenericMessage));
  });

  test('sin respuesta da el error de conexión', () async {
    final (repo, _) = _api(0, null, offline: true);

    await expectLater(repo.get(), _apiMessage(kApiNoConnectionMessage));
  });
}
