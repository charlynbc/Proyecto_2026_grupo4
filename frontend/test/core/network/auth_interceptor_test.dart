import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_routes.dart';
import 'package:agenda_medica/core/network/auth_interceptor.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/auth/repositories/api_auth_repository.dart';
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
      // Simula el cookie jar del navegador/Android: va después del
      // AuthInterceptor, como el adapter real, y solo manda la cookie al
      // refresh y al logout.
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            if (o.path == ApiRoutes.authRefresh ||
                o.path == ApiRoutes.authLogout) {
              o.headers['Cookie'] = 'refresh_token=rt1';
            }
            h.next(o);
          },
        ),
      );
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

  group('refresh y logout con access token vencido', () {
    String bearer(String token) => 'Bearer $token';
    final logoutTokens = <String?>[];
    setUp(logoutTokens.clear);

    // Backend simulado: el refresh exige la cookie y rechaza cualquier
    // Authorization; el logout exige el access token vigente.
    FutureOr<ResponseBody> backend(
      RequestOptions o, {
      List<RequestOptions>? refreshes,
      List<RequestOptions>? logouts,
    }) {
      if (o.path == ApiRoutes.authRefresh) {
        refreshes?.add(o);
        if (o.headers.containsKey('Authorization')) {
          return _json(401, {'code': 'TOKEN_VENCIDO'});
        }
        if (o.headers['Cookie'] != 'refresh_token=rt1') {
          return _json(401, {'code': 'SESION_INVALIDA'});
        }
        return _json(200, sessionBody('nuevo'));
      }
      if (o.path == ApiRoutes.authLogout) {
        logouts?.add(o);
        logoutTokens.add(o.headers['Authorization'] as String?);
        if (o.headers['Authorization'] == bearer('nuevo')) {
          return ResponseBody.fromString(
            '',
            204,
            headers: {
              'set-cookie': ['refresh_token=; Max-Age=0; HttpOnly'],
            },
          );
        }
      }
      return _json(401, {'code': 'NO_AUTENTICADO'});
    }

    test('el refresh nunca lleva Authorization y sí la cookie', () async {
      final refreshes = <RequestOptions>[];
      setUpWith((o) => backend(o, refreshes: refreshes));
      startSession();

      await dio.get<void>(_protected).then((_) {}, onError: (_) {});

      expect(refreshes, hasLength(1));
      expect(refreshes.single.headers.containsKey('Authorization'), isFalse);
      expect(refreshes.single.headers['Cookie'], 'refresh_token=rt1');
    });

    test('un Authorization puesto a mano en el refresh se descarta', () async {
      final refreshes = <RequestOptions>[];
      setUpWith((o) => backend(o, refreshes: refreshes));
      startSession();

      final response = await dio.post<Map<String, dynamic>>(
        ApiRoutes.authRefresh,
        options: Options(headers: {'Authorization': bearer('viejo')}),
      );

      expect(response.statusCode, 200);
      expect(refreshes.single.headers.containsKey('Authorization'), isFalse);
    });

    test('las demás requests autenticadas siguen llevando el bearer', () async {
      String? header;
      setUpWith((o) {
        header = o.headers['Authorization'] as String?;
        return _json(200, {'ok': true});
      });
      startSession();

      await dio.get<void>(_protected);

      expect(header, bearer('viejo'));
    });

    test('logout con token válido no pide refresh', () async {
      final logouts = <RequestOptions>[];
      setUpWith((o) => backend(o, logouts: logouts));
      container
          .read(sessionProvider.notifier)
          .setAuthenticated(accessToken: 'nuevo', role: UserRole.socio);

      final response = await dio.post<void>(ApiRoutes.authLogout);

      expect(response.statusCode, 204);
      expect(response.headers['set-cookie'], isNotEmpty);
      expect(adapter.paths, [ApiRoutes.authLogout]);
      expect(logouts.single.headers['Cookie'], 'refresh_token=rt1');
    });

    test('logout con token vencido: refresh sin bearer y reintento', () async {
      final logouts = <RequestOptions>[];
      final refreshes = <RequestOptions>[];
      setUpWith((o) => backend(o, logouts: logouts, refreshes: refreshes));
      startSession();

      final response = await dio.post<void>(ApiRoutes.authLogout);

      expect(response.statusCode, 204);
      expect(response.headers['set-cookie']!.single, contains('Max-Age=0'));
      expect(adapter.paths, [
        ApiRoutes.authLogout,
        ApiRoutes.authRefresh,
        ApiRoutes.authLogout,
      ]);
      expect(logoutTokens, [bearer('viejo'), bearer('nuevo')]);
      expect(refreshes.single.headers.containsKey('Authorization'), isFalse);
    });

    test('el repository limpia la sesión local tras el logout', () async {
      setUpWith((o) => backend(o));
      startSession();
      final repository = ApiAuthRepository(
        dio,
        container.read(sessionProvider.notifier),
      );

      await repository.logout();

      final session = container.read(sessionProvider);
      expect(session.status, SessionStatus.unauthenticated);
      expect(session.expired, isFalse);
    });

    test('logout con refresh rechazado: sin bucle y sesión cerrada', () async {
      setUpWith((o) {
        if (o.path == ApiRoutes.authRefresh) {
          return _json(401, {'code': 'SESION_INVALIDA'});
        }
        return _json(401, {'code': 'NO_AUTENTICADO'});
      });
      startSession();

      await expectLater(
        dio.post<void>(ApiRoutes.authLogout),
        throwsA(isA<DioException>()),
      );

      expect(adapter.paths, [ApiRoutes.authLogout, ApiRoutes.authRefresh]);
      expect(container.read(sessionProvider).expired, isTrue);
    });

    test('logout con error de red en el refresh: no reintenta', () async {
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

      await expectLater(
        dio.post<void>(ApiRoutes.authLogout),
        throwsA(isA<DioException>()),
      );

      expect(adapter.paths, [ApiRoutes.authLogout, ApiRoutes.authRefresh]);
      expect(container.read(sessionProvider).isAuthenticated, isTrue);
    });

    test('si el logout reintentado sigue en 401 no hay segundo refresh', () async {
      setUpWith((o) {
        if (o.path == ApiRoutes.authRefresh) {
          return _json(200, sessionBody('nuevo'));
        }
        return _json(401, {'code': 'NO_AUTENTICADO'});
      });
      startSession();

      await expectLater(
        dio.post<void>(ApiRoutes.authLogout),
        throwsA(isA<DioException>()),
      );

      expect(adapter.paths, [
        ApiRoutes.authLogout,
        ApiRoutes.authRefresh,
        ApiRoutes.authLogout,
      ]);
      expect(container.read(sessionProvider).expired, isTrue);
    });

    test('401 concurrentes comparten un solo refresh', () async {
      final refreshes = <RequestOptions>[];
      setUpWith((o) {
        if (o.path == ApiRoutes.authRefresh || o.path == ApiRoutes.authLogout) {
          return backend(o, refreshes: refreshes);
        }
        return o.headers['Authorization'] == bearer('nuevo')
            ? _json(200, {'ok': true})
            : _json(401, {'code': 'NO_AUTENTICADO'});
      });
      startSession();

      final results = await Future.wait([
        dio.get<void>(_protected),
        dio.get<void>(_protected),
        dio.get<void>(_protected),
      ]);

      expect(results.map((r) => r.statusCode), everyElement(200));
      expect(refreshes, hasLength(1));
    });
  });

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

  group('rutas de enlace: se autorizan con el token del correo', () {
    // Escritas a mano (contrato, filas 5, 49, 50, 63 y 64): si alguien saca
    // una de la lista del interceptor, cae el test de esa ruta.
    const linkPaths = [
      '/api/auth/primer-ingreso/validar',
      '/api/auth/primer-ingreso/completar',
      '/api/auth/recuperacion/validar',
      '/api/auth/recuperacion/completar',
      '/api/auth/cambio-correo/confirmar',
    ];
    const linkBody = {'token': 'abc123'};

    for (final path in linkPaths) {
      test('$path sale sin Authorization aunque haya sesión', () async {
        Map<String, dynamic>? sent;
        setUpWith((o) {
          sent = Map.of(o.headers);
          return ResponseBody.fromString('', 200);
        });
        startSession();

        await dio.post<void>(path, data: linkBody);

        expect(sent!.containsKey('Authorization'), isFalse);
      });

      test(
        'un 401 en $path no renueva, no reintenta ni cierra la sesión',
        () async {
          setUpWith((o) {
            if (o.path == ApiRoutes.authRefresh) {
              return _json(200, sessionBody('nuevo'));
            }
            // El backend responde así a un Bearer inválido: 401 sin cuerpo.
            return ResponseBody.fromString('', 401);
          });
          startSession();

          await expectLater(
            dio.post<void>(path, data: linkBody),
            throwsA(
              isA<DioException>().having(
                (e) => e.response?.statusCode,
                'statusCode',
                401,
              ),
            ),
          );

          expect(adapter.paths, [path]);
          final session = container.read(sessionProvider);
          expect(session.isAuthenticated, isTrue);
          expect(session.accessToken, 'viejo');
          expect(session.expired, isFalse);
        },
      );
    }

    test(
      'un Authorization puesto a mano en una ruta de enlace se descarta',
      () async {
        Map<String, dynamic>? sent;
        setUpWith((o) {
          sent = Map.of(o.headers);
          return ResponseBody.fromString('', 200);
        });
        startSession();

        await dio.post<void>(
          '/api/auth/cambio-correo/confirmar',
          data: linkBody,
          options: Options(headers: {'Authorization': 'Bearer viejo'}),
        );

        expect(sent!.containsKey('Authorization'), isFalse);
      },
    );

    test('la ruta de consultas del socio sigue llevando el Bearer', () async {
      String? header;
      setUpWith((o) {
        header = o.headers['Authorization'] as String?;
        return _json(200, {'ok': true});
      });
      startSession();

      await dio.get<void>('/api/consultas');

      expect(header, 'Bearer viejo');
    });
  });
}
