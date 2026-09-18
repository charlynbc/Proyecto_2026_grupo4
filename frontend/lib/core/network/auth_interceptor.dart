import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/session_provider.dart';

/// Agrega el header `Authorization` con el access token en memoria, y ante
/// un 401 llama a `POST /api/auth/refresh` y reintenta la request original.
///
/// Recibe el [Dio] al que se lo agrega (capturado antes de
/// `dio.interceptors.add(...)` en `dioProvider`) y lo usa tanto para la
/// llamada de refresh como para el retry, en vez de una instancia de `Dio`
/// separada solo para refresh: con dos instancias, en Android cada una arma
/// su propio `PersistCookieJar` sobre el mismo directorio pero con caché en
/// memoria independiente, así que una rotación de cookie hecha por una no
/// la ve la otra.
///
/// También recibe el [Ref] de `dioProvider` en vez de un [SessionNotifier]
/// directo: el getter `state` de [Notifier] es `@visibleForTesting`, así
/// que leer el estado actual desde afuera del propio notifier tiene que
/// pasar por `ref.read(sessionProvider)`.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._ref);

  static const _refreshPath = '/api/auth/refresh';

  final Dio _dio;
  final Ref _ref;

  /// Future compartido para serializar los 401 concurrentes: solo el
  /// primero dispara un refresh, el resto espera el mismo Future.
  Future<void>? _refreshing;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(sessionProvider).accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final isRefreshCall = err.requestOptions.path == _refreshPath;
    if (isRefreshCall || err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    try {
      await (_refreshing ??=
          _refresh().whenComplete(() => _refreshing = null));
    } catch (_) {
      // Acá sí había una sesión activa (se estaba reintentando un request
      // con token) y el refresh también falló: es una expiración real.
      _ref.read(sessionProvider.notifier).clear(expired: true);
      handler.next(err);
      return;
    }

    try {
      // Vuelve a pasar por onRequest, que relee el token ya renovado.
      handler.resolve(await _dio.fetch<dynamic>(err.requestOptions));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<void> _refresh() async {
    final response = await _dio.post<Map<String, dynamic>>(_refreshPath);
    final data = response.data!;
    _ref.read(sessionProvider.notifier).setAuthenticated(
          accessToken: data['token'] as String,
          role: data['role'] as String,
        );
  }
}
