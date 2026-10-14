import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import '../providers/session_provider.dart';
import 'auth_repository.dart';

/// Implementación real de [AuthRepository] contra el backend, vía
/// [dioProvider] (ver `core/network/dio_client.dart`). El resultado de cada
/// llamada se guarda en [SessionNotifier], nunca se persiste.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._dio, this._session);

  final Dio _dio;
  final SessionNotifier _session;

  @override
  Future<void> login({required String ci, required String password}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.authLogin,
        data: {'cedula': ci, 'clave': password},
      );
      _applySession(response.data!);
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
      _applySession(response.data!);
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

  void _applySession(Map<String, dynamic> data) {
    _session.setAuthenticated(
      accessToken: data['token'] as String,
      role: data['role'] as String,
    );
  }

  /// Distingue credenciales inválidas del resto por el campo `code` de
  /// `{"code": "...", "message": "..."}`, nunca comparando el texto de
  /// `message`. Un `DioException` sin `response` (timeout, sin conexión)
  /// también cae acá.
  Never _throwMapped(DioException e) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] as String? : null;
    if (code == 'CREDENCIALES_INVALIDAS') {
      throw const InvalidCredentialsException();
    }
    final message = data is Map ? data['message'] as String? : null;
    if (message != null) {
      throw AuthException(message);
    }
    throw const AuthException();
  }
}
