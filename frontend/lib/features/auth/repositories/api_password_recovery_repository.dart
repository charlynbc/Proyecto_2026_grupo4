import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import '../models/access_type.dart';
import 'auth_errors.dart';
import 'password_recovery_repository.dart';

/// Implementación real de [PasswordRecoveryRepository] (contrato, filas 48 y
/// 49). Las dos llamadas son públicas: no llevan sesión.
class ApiPasswordRecoveryRepository implements PasswordRecoveryRepository {
  ApiPasswordRecoveryRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> requestLink({
    required String ci,
    required AccessType access,
  }) async {
    try {
      await _dio.post<void>(
        ApiRoutes.authPasswordRecoveryRequest,
        data: {'ci': ci, 'acceso': access.apiValue},
      );
    } on DioException catch (e) {
      throw authExceptionFrom(e);
    }
  }

  @override
  Future<void> complete({
    required String token,
    required String password,
  }) async {
    try {
      await _dio.post<void>(
        ApiRoutes.authPasswordRecoveryComplete,
        data: {'token': token, 'password': password},
      );
    } on DioException catch (e) {
      if (apiErrorCode(e) == 'ENLACE_INVALIDO') {
        final message = _serverMessage(e);
        throw message == null
            ? const InvalidRecoveryLinkException()
            : InvalidRecoveryLinkException(message);
      }
      throw authExceptionFrom(e);
    }
  }

  /// El `message` del error uniforme, si viene y no está vacío.
  String? _serverMessage(DioException e) {
    final data = e.response?.data;
    final message = data is Map ? data['message'] as String? : null;
    return message == null || message.trim().isEmpty ? null : message;
  }
}
