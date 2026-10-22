import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/api_auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CaptureAdapter implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode({
        'token': 'jwt',
        'tokenType': 'Bearer',
        'expiresIn': 900,
        'role': 'FUNCIONARIO',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('el login envía ci, password, acceso y plataforma', () async {
    final adapter = _CaptureAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await ApiAuthRepository(
      dio,
      container.read(sessionProvider.notifier),
    ).login(ci: '12345678', password: 'secreta', access: AccessType.empleado);

    final body = adapter.last!.data as Map<String, dynamic>;
    expect(adapter.last!.path, '/api/auth/login');
    expect(body['ci'], '12345678');
    expect(body['password'], 'secreta');
    expect(body['acceso'], 'EMPLEADO');
    expect(body['plataforma'], kIsWeb ? 'WEB' : 'ANDROID');
    expect(body.containsKey('cedula'), isFalse);
    expect(body.containsKey('clave'), isFalse);
  });
}
