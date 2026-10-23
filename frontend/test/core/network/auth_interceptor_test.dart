import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:agenda_medica/core/network/auth_interceptor.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Handler = FutureOr<ResponseBody> Function(RequestOptions options);

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _Handler handler;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Un repository que nunca termina de refrescar: evita que el bootstrap de la
/// sesión pise el estado que arma cada test.
class _IdleAuthRepository implements AuthRepository {
  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) => Completer<void>().future;

  @override
  Future<void> refresh() => Completer<void>().future;

  @override
  Future<void> logout() => Completer<void>().future;
}

const _protected = ApiRoutes.availability;

void main() {
  late _FakeAdapter adapter;
  late ProviderContainer container;
  late Dio dio;

  void setUpWith(_Handler handler) {
    adapter = _FakeAdapter(handler);
    final dioProvider = Provider<Dio>((ref) {
      final dio = Dio(BaseOptions(baseUrl: 'http://prueba'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(AuthInterceptor(dio, ref));
      return dio;
    });
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith(
          (ref) async => _IdleAuthRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    dio = container.read(dioProvider);
  }

  void startSession() => container
      .read(sessionProvider.notifier)
      .setAuthenticated(accessToken: 'viejo', role: UserRole.socio);

  Map<String, dynamic> sessionBody(String token) => {
    'token': token,
    'role': 'SOCIO',
  };

  test(
    'un 401 del login (sin token) no intenta renovar ni marca sesión caída',
    () async {
      setUpWith((o) => _json(401, {'code': 'CREDENCIALES_INVALIDAS'}));
      container.read(sessionProvider.notifier).clear();

      await expectLater(
        dio.post<void>(ApiRoutes.authLogin),
        throwsA(isA<DioException>()),
      );

      expect(adapter.paths, [ApiRoutes.authLogin]);
      expect(container.read(sessionProvider).expired, isFalse);
    },
  );

  test('si el refresh responde 401 la sesión se cierra con aviso', () async {
    setUpWith((o) {
      if (o.path == ApiRoutes.authRefresh) {
        return _json(401, {'code': 'SESION_INVALIDA'});
      }
      return _json(401, {'code': 'NO_AUTENTICADO'});
    });
    startSession();

    await expectLater(dio.get<void>(_protected), throwsA(isA<DioException>()));

    final session = container.read(sessionProvider);
    expect(session.status, SessionStatus.unauthenticated);
    expect(session.expired, isTrue);
  });

  test('con refresh correcto reintenta con el token nuevo', () async {
    String? retriedWith;
    setUpWith((o) {
      if (o.path == ApiRoutes.authRefresh) {
        return _json(200, sessionBody('nuevo'));
      }
      retriedWith = o.headers['Authorization'] as String?;
      return retriedWith == 'Bearer nuevo'
          ? _json(200, {'ok': true})
          : _json(401, {'code': 'NO_AUTENTICADO'});
    });
    startSession();

    final response = await dio.get<Map<String, dynamic>>(_protected);

    expect(response.data, {'ok': true});
    expect(retriedWith, 'Bearer nuevo');
    expect(container.read(sessionProvider).isAuthenticated, isTrue);
    expect(container.read(sessionProvider).expired, isFalse);
  });

  test('logout renueva el access token vencido y reintenta', () async {
    var logoutCalls = 0;
    final logoutAuthorizationHeaders = <String?>[];
    setUpWith((o) {
      if (o.path == ApiRoutes.authRefresh) {
        return _json(200, sessionBody('nuevo'));
      }
      if (o.path == ApiRoutes.authLogout) {
        logoutAuthorizationHeaders.add(
          o.headers['Authorization'] as String?,
        );
        logoutCalls++;
        if (logoutCalls == 2) {
          return ResponseBody.fromString('', 204);
        }
      }
      return _json(401, {'code': 'NO_AUTENTICADO'});
    });
    startSession();

    final response = await dio.post<void>(ApiRoutes.authLogout);

    expect(response.statusCode, 204);
    expect(logoutAuthorizationHeaders, hasLength(2));
    expect(logoutAuthorizationHeaders, everyElement(isNotNull));
    expect(
      adapter.paths,
      [ApiRoutes.authLogout, ApiRoutes.authRefresh, ApiRoutes.authLogout],
    );
  });

  test(
    'si tras renovar el servidor sigue dando 401, la sesión se cierra',
    () async {
      setUpWith((o) {
        if (o.path == ApiRoutes.authRefresh) {
          return _json(200, sessionBody('nuevo'));
        }
        return _json(401, {'code': 'NO_AUTENTICADO'});
      });
      startSession();

      await expectLater(
        dio.get<void>(_protected),
        throwsA(isA<DioException>()),
      );

      expect(
        adapter.paths.where((p) => p == ApiRoutes.authRefresh),
        hasLength(1),
      );
      final session = container.read(sessionProvider);
      expect(session.status, SessionStatus.unauthenticated);
      expect(session.expired, isTrue);
    },
  );

  test('un corte de red durante el refresh no cierra la sesión', () async {
    setUpWith((o) {
      if (o.path == ApiRoutes.authRefresh) {
        throw DioException.connectionError(
          requestOptions: o,
          reason: 'sin conexión',
        );
      }
      return _json(401, {'code': 'NO_AUTENTICADO'});
    });
    startSession();

    await expectLater(dio.get<void>(_protected), throwsA(isA<DioException>()));

    expect(container.read(sessionProvider).isAuthenticated, isTrue);
  });
}
