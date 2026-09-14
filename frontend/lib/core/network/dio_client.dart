import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'http_client_adapter_stub.dart'
    if (dart.library.js_interop) 'http_client_adapter_web.dart'
    if (dart.library.html) 'http_client_adapter_web.dart' as platform_adapter;

/// Cliente HTTP central de la app. Todas las features lo consumen a través
/// de [dioProvider] en vez de instanciar su propio `Dio`.
///
/// El token de sesión viaja en cookies `HttpOnly` `Secure` `SameSite` que
/// maneja el navegador solo: nunca se lee ni se guarda desde Dart. Por eso
/// alcanza con configurar el adapter para que las mande; no hay headers de
/// auth que agregar acá.
///
/// TODO: baseUrl y endpoints de auth los define el backend, que todavía no
/// existe. El interceptor de refresh de sesión se agrega recién cuando haya
/// contrato: no inventar rutas ni payloads.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      // baseUrl vacía a propósito: se completa cuando el backend esté disponible.
      baseUrl: '',
    ),
  );
  platform_adapter.configureCredentials(dio);
  return dio;
});
