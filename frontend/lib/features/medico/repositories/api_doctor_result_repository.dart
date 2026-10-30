import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/doctor_appointment_result.dart';
import 'doctor_result_repository.dart';

/// Implementación real de [DoctorResultRepository]. Una respuesta mal formada
/// se vuelve el error genérico: no se rellena nada.
class ApiDoctorResultRepository implements DoctorResultRepository {
  ApiDoctorResultRepository(this._dio);

  final Dio _dio;

  @override
  Future<AppointmentResult> register(
    int appointmentId,
    AppointmentResultRequest request,
  ) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiRoutes.doctorAppointmentResult(appointmentId),
      data: request.toJson(),
    );
    return AppointmentResult.fromJson(
      response.data ?? (throw const ApiException()),
    );
  });

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

  /// Los mensajes de cada caso son propios: el texto del servidor no se
  /// muestra. Un código desconocido cae en el error de [ApiException.fromDio].
  ApiException _mapError(DioException e) {
    return switch (apiCodeOf(e)) {
      'VALIDACION' => const ResultValidationException(),
      'CONFLICTO_DE_INTERES' => const ConflictOfInterestException(),
      'NO_ENCONTRADO' => const ResultAppointmentNotFoundException(),
      'CONSULTA_NO_AGENDADA' => const AppointmentNotScheduledException(),
      'CONSULTA_NO_ES_DE_HOY' => const AppointmentNotTodayException(),
      'SIN_AVISO_LLEGADA' => const NoArrivalNoticeException(),
      'PASE_DUPLICADO' => const DuplicateReferralException(),
      _ => ApiException.fromDio(e),
    };
  }
}
