import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_client_adapter_stub.dart'
    if (dart.library.js_interop) 'http_client_adapter_web.dart'
    if (dart.library.html) 'http_client_adapter_web.dart' as platform_adapter;

/// Cliente HTTP central de la app. Todas las features lo consumen a través
/// de [dioProvider] en vez de instanciar su propio `Dio`.
///
/// `baseUrl` se puede sobreescribir en build/run con
/// `--dart-define=API_BASE_URL=...`; por defecto apunta al backend local.
///
/// El token de sesión viaja en cookies `HttpOnly` que maneja el navegador (o,
/// en Android, un `PersistCookieJar` propio, ver `http_client_adapter_stub.dart`)
/// sin que Dart las lea ni las guarde. Por eso alcanza con configurar el
/// adapter para que las mande; no hay headers de auth que agregar acá.
///
/// TODO: el interceptor de refresh de sesión (access token en memoria,
/// header Authorization, reintento tras 401) se agrega cuando la feature de
/// auth se conecte al backend real.
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
  return dio;
});
