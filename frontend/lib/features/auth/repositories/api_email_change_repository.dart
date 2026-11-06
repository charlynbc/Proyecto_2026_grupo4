import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import 'auth_errors.dart';
import 'email_change_repository.dart';

/// Implementación real de [EmailChangeRepository] (contrato, fila 50). Es
/// pública: autoriza el token del enlace, no la sesión.
class ApiEmailChangeRepository implements EmailChangeRepository {
  ApiEmailChangeRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> confirm({required String token}) async {
    try {
      await _dio.post<void>(
        ApiRoutes.authEmailChangeConfirm,
        data: {'token': token},
      );
    } on DioException catch (e) {
      if (apiErrorCode(e) == 'ENLACE_INVALIDO') {
        final message = _serverMessage(e);
        throw message == null
            ? const InvalidEmailChangeLinkException()
            : InvalidEmailChangeLinkException(message);
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
