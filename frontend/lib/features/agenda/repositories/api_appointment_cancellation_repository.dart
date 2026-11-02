import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/cancellation_result.dart';
import 'appointment_cancellation_repository.dart';

class ApiAppointmentCancellationRepository
    implements AppointmentCancellationRepository {
  ApiAppointmentCancellationRepository(this._dio);

  final Dio _dio;

  @override
  Future<CancellationResult> cancel(int id) async {
    if (id <= 0) {
      throw const CancellationException(
        CancellationFailure.notFound,
        'No encontramos la consulta.',
      );
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.appointmentCancel(id),
      );
      return CancellationResult.fromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  CancellationException _mapError(DioException error) {
    final message = ApiException.fromDio(error).message;
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    final failure = switch ((status, code)) {
      (_, 'NO_ENCONTRADO') => CancellationFailure.notFound,
      (_, 'CONSULTA_NO_AGENDADA') => CancellationFailure.notScheduled,
      (_, 'CANCELACION_FUERA_DE_PLAZO') => CancellationFailure.outsideWindow,
      (_, 'LLEGADA_YA_REGISTRADA') => CancellationFailure.alreadyArrived,
      (_, 'VALIDACION') => CancellationFailure.validation,
      (_, 'NO_AUTENTICADO') => CancellationFailure.unauthenticated,
      (_, 'ACCESO_DENEGADO') => CancellationFailure.forbidden,
      (401, _) => CancellationFailure.unauthenticated,
      (403, _) => CancellationFailure.forbidden,
      _ => CancellationFailure.other,
    };
    return CancellationException(failure, message);
  }
}
