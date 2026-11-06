import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import 'auth_errors.dart';
import 'password_recovery_link_repository.dart';
import 'password_recovery_repository.dart';

/// Implementación real de [PasswordRecoveryLinkRepository] (contrato, fila
/// 64). Es pública: no lleva sesión, y el token va en el cuerpo, nunca en la
/// URL.
class ApiPasswordRecoveryLinkRepository
    implements PasswordRecoveryLinkRepository {
  ApiPasswordRecoveryLinkRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> validateLink({required String token}) async {
    try {
      await _dio.post<void>(
        ApiRoutes.authPasswordRecoveryValidate,
        data: {'token': token},
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
    return message == null || message.isEmpty ? null : message;
  }
}
