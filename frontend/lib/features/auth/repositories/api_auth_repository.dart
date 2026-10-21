import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import '../models/access_type.dart';
import '../providers/session_provider.dart';
import 'auth_errors.dart';
import 'auth_repository.dart';

/// Implementación real de [AuthRepository] contra el backend, vía
/// [dioProvider] (ver `core/network/dio_client.dart`). El resultado de cada
/// llamada se guarda en [SessionNotifier], nunca se persiste.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._session);

  final Dio _dio;
  final SessionNotifier _session;

  @override
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.authLogin,
        data: {'ci': ci, 'password': password, 'acceso': access.apiValue},
      );
      _applySession(response.data);
    } on DioException catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> refresh() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.authRefresh,
      );
      _applySession(response.data);
    } on DioException catch (e) {
      _throwMapped(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<void>(ApiRoutes.authLogout);
    } on DioException catch (e) {
      _throwMapped(e);
    } finally {
      _session.clear();
    }
  }

  void _applySession(Map<String, dynamic>? data) {
    try {
      _session.setAuthenticatedFromResponse(data ?? const {});
    } on FormatException {
      throw const AuthException();
    }
  }

  /// Distingue credenciales inválidas del resto por el campo `code` de
  /// `{"code": "...", "message": "..."}`, nunca comparando el texto de
  /// `message`. Un `DioException` sin `response` (timeout, sin conexión)
  /// también cae acá.
  Never _throwMapped(DioException e) {
    if (apiErrorCode(e) == 'CREDENCIALES_INVALIDAS') {
      throw const InvalidCredentialsException();
    }
    throw authExceptionFrom(e);
  }
}
