import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import 'auth_errors.dart';
import 'first_login_link_repository.dart';
import 'first_login_repository.dart';

/// Implementación real de [FirstLoginLinkRepository] (contrato, fila 63). Es
/// pública: no lleva sesión, y el token va en el cuerpo, nunca en la URL.
class ApiFirstLoginLinkRepository implements FirstLoginLinkRepository {
  ApiFirstLoginLinkRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> validateLink({required String token}) async {
    try {
      await _dio.post<void>(
        ApiRoutes.authFirstLoginValidate,
        data: {'token': token},
      );
    } on DioException catch (e) {
      if (apiErrorCode(e) == 'ENLACE_INVALIDO') {
        final data = e.response?.data;
        final message = data is Map ? data['message'] : null;
        throw message is String && message.trim().isNotEmpty
            ? InvalidActivationLinkException(message)
            : const InvalidActivationLinkException();
      }
      throw authExceptionFrom(e);
    }
  }
}
