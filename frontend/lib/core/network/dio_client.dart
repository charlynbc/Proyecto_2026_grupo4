import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_interceptor.dart';
import 'http_client_adapter_stub.dart'
    if (dart.library.js_interop) 'http_client_adapter_web.dart'
    if (dart.library.html) 'http_client_adapter_web.dart' as platform_adapter;

/// Cliente HTTP central de la app. Todas las features lo consumen a través
/// de [dioProvider] en vez de instanciar su propio `Dio`.
///
/// `baseUrl` se puede sobreescribir en build/run con
/// `--dart-define=API_BASE_URL=...`; por defecto apunta al backend local.
///
/// El refresh token viaja en una cookie `HttpOnly` que maneja el navegador
/// (o, en Android, un `PersistCookieJar` propio, ver
/// `http_client_adapter_stub.dart`) sin que Dart la lea ni la guarde; por
/// eso alcanza con configurar el adapter para que la mande. El access token
/// sí lo agrega [AuthInterceptor] como header `Authorization` en cada
/// request, leyéndolo del estado de sesión en memoria.
final dioProvider = FutureProvider<Dio>((ref) async {
  final dio = Dio(
    BaseOptions(
      baseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:8080',
      ),
    ),
  );
  await platform_adapter.configureCredentials(dio);
  dio.interceptors.add(AuthInterceptor(dio, ref));
  return dio;
});
