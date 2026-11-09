import 'package:dio/dio.dart';

import '../../../core/network/api_routes.dart';
import '../models/access_type.dart';
import 'auth_errors.dart';
import 'first_login_repository.dart';

/// Implementación real de [FirstLoginRepository] (contrato #4 y #5). Ninguna
/// de las dos llamadas lleva sesión: son públicas.
class ApiFirstLoginRepository implements FirstLoginRepository {
  ApiFirstLoginRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> requestLink({
    required String ci,
    required AccessType access,
  }) async {
    try {
      await _dio.post<void>(
        ApiRoutes.authFirstLoginRequest,
        data: {'ci': ci, 'acceso': access.apiValue},
      );
    } on DioException catch (e) {
      throw authExceptionFrom(e);
    }
  }

  @override
  Future<AccessType> activate({
    required String token,
    required String address,
    required String phone1,
    String? phone2,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.authFirstLoginComplete,
        data: {
          'token': token,
          'direccion': address,
          'telefono1': phone1,
          'telefono2': phone2,
          'password': password,
        },
      );
      // La cuenta sabe por dónde se ingresa: SOCIO por el acceso de socios,
      // cualquier otro rol por el de empleados.
      final role = response.data?['rol'];
      return role == null || role == 'SOCIO'
          ? AccessType.socio
          : AccessType.empleado;
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
