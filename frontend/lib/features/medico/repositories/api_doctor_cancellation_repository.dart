import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/doctor_cancellation_result.dart';
import 'doctor_cancellation_repository.dart';

/// Implementación real de [DoctorCancellationRepository]. El plazo de 2 horas
/// y el conflicto de interés los decide el servidor.
class ApiDoctorCancellationRepository implements DoctorCancellationRepository {
  ApiDoctorCancellationRepository(this._dio);

  final Dio _dio;

  @override
  Future<DoctorCancellationResult> cancelAppointment(
    int appointmentId,
    String reason,
  ) async {
    final trimmed = reason.trim();
    if (appointmentId <= 0 || trimmed.isEmpty || trimmed.length > 1000) {
      throw DoctorCancellationException(
        DoctorCancellationFailure.validation,
        cancelAppointmentMessage(DoctorCancellationFailure.validation),
      );
    }
    return _request(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.doctorAppointmentCancel(appointmentId),
        data: {'motivo': trimmed},
      );
      return DoctorCancellationResult.fromJson(
        response.data ?? (throw const ApiException()),
      );
    });
  }

  /// Corre el pedido y traduce sus fallas: las de la red o del servidor por su
  /// `code`, y una respuesta mal formada como el error genérico.
  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapError(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  /// Traduce el `code` a un fallo con mensaje propio. El 401
  /// (`NO_AUTENTICADO` o `TOKEN_INVALIDO`) no tiene rama: lo resuelve el
  /// interceptor de sesión. Ese 401, un 500 y cualquier otro código caen en
  /// [ApiException.fromDio], que muestra el texto del servidor.
  ApiException _mapError(DioException e) {
    // Un JSON que no se puede leer llega sin respuesta. No es falta de red.
    if (e.error is FormatException) return const ApiException();
    final failure = switch (apiCodeOf(e)) {
      'VALIDACION' => DoctorCancellationFailure.validation,
      'ACCESO_DENEGADO' => DoctorCancellationFailure.forbidden,
      'CONFLICTO_DE_INTERES' => DoctorCancellationFailure.conflictOfInterest,
      'NO_ENCONTRADO' => DoctorCancellationFailure.notFound,
      'CONSULTA_NO_AGENDADA' => DoctorCancellationFailure.notScheduled,
      'CANCELACION_FUERA_DE_PLAZO' => DoctorCancellationFailure.outsideWindow,
      _ => null,
    };
    if (failure == null) return ApiException.fromDio(e);
    return DoctorCancellationException(
      failure,
      cancelAppointmentMessage(failure),
    );
  }
}
