import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/session_provider.dart';
import 'api_routes.dart';

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
///
/// Solo se intenta renovar la sesión cuando la request llevaba token: un 401
/// de una request pública (el login con credenciales incorrectas, el primer
/// ingreso) no es una sesión caída. La sesión se da por terminada (con el
/// aviso de sesión cerrada) solo cuando el servidor la rechaza de verdad:
/// el refresh responde 401 o 403, o la request reintentada con el token
/// nuevo vuelve a dar 401 (sesión revocada o cuenta inactivada). Un corte de
/// red durante el refresh no cierra la sesión.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._ref);

  static const _refreshPath = ApiRoutes.authRefresh;
  static const _retriedKey = 'authRetried';

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
    final options = err.requestOptions;
    final isSessionRequest =
        options.headers.containsKey('Authorization') &&
        options.path != _refreshPath;
    if (err.response?.statusCode != 401 || !isSessionRequest) {
      handler.next(err);
      return;
    }

    if (options.extra[_retriedKey] == true) {
      // Con el token recién renovado el servidor volvió a decir 401: la
      // sesión fue revocada o la cuenta inactivada.
      _expireSession();
      handler.next(err);
      return;
    }

    try {
      await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
    } catch (e) {
      if (_isRejectedByServer(e)) _expireSession();
      handler.next(err);
      return;
    }

    try {
      // Vuelve a pasar por onRequest, que relee el token ya renovado.
      options.extra[_retriedKey] = true;
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  void _expireSession() =>
      _ref.read(sessionProvider.notifier).clear(expired: true);

  /// El servidor respondió que la sesión no sirve (401 o 403 del refresh) o
  /// devolvió una sesión que no se entiende. Cualquier otra falla (sin
  /// conexión, timeout, 5xx) no dice nada sobre la sesión.
  bool _isRejectedByServer(Object e) {
    if (e is FormatException) return true;
    if (e is! DioException) return false;
    final status = e.response?.statusCode;
    return status == 401 || status == 403;
  }

  Future<void> _refresh() async {
    final response = await _dio.post<Map<String, dynamic>>(_refreshPath);
    _ref
        .read(sessionProvider.notifier)
        .setAuthenticatedFromResponse(response.data ?? const {});
  }
}
