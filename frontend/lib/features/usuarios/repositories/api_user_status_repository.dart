import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/account_status_change.dart';
import 'user_status_repository.dart';

/// Implementación real de [UserStatusRepository] (contrato, filas 61 y 62).
/// Una respuesta mal formada se vuelve el error genérico.
class ApiUserStatusRepository implements UserStatusRepository {
  ApiUserStatusRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountStatusChange> deactivate(int id) =>
      _post(id, ApiRoutes.userDeactivate);

  @override
  Future<AccountStatusChange> reactivate(int id) =>
      _post(id, ApiRoutes.userReactivate);

  Future<AccountStatusChange> _post(int id, String Function(int) route) async {
    if (id <= 0) {
      throw const UserStatusException(
        UserStatusFailure.notFound,
        'No se encontró la cuenta.',
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(route(id));
      return AccountStatusChange.fromJson(
        response.data ?? (throw const FormatException()),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    } on FormatException {
      throw const UserStatusException(UserStatusFailure.other);
    } on TypeError {
      throw const UserStatusException(UserStatusFailure.other);
    }
  }

  /// Distingue los casos por su `code`; el mensaje es el del servidor.
  UserStatusException _mapError(DioException e) {
    final failure = switch (apiCodeOf(e)) {
      'USUARIO_NO_ENCONTRADO' => UserStatusFailure.notFound,
      'CUENTA_YA_INACTIVA' => UserStatusFailure.alreadyInactive,
      'CUENTA_YA_ACTIVA' => UserStatusFailure.alreadyActive,
      'MEDICO_CON_TURNOS_ACTIVOS' => UserStatusFailure.doctorHasShifts,
      'MEDICO_CON_CONSULTAS_AGENDADAS' =>
        UserStatusFailure.doctorHasAppointments,
      'EMPLEADO_DUPLICADO' => UserStatusFailure.duplicateStaff,
      'VALIDACION' => UserStatusFailure.validation,
      _ => UserStatusFailure.other,
    };
    return UserStatusException(failure, ApiException.fromDio(e).message);
  }
}
