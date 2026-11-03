import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_routes.dart';
import '../../../agenda/models/agenda_time.dart';
import '../models/appointment_statistics.dart';
import 'appointment_statistics_repository.dart';

class ApiAppointmentStatisticsRepository
    implements AppointmentStatisticsRepository {
  ApiAppointmentStatisticsRepository(this._dio);

  final Dio _dio;

  @override
  Future<AppointmentStatistics> statistics({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.statsAppointments,
        queryParameters: {
          if (from != null) 'desde': formatApiDate(from),
          if (to != null) 'hasta': formatApiDate(to),
        },
      );
      return AppointmentStatistics.fromJson(
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

  AppointmentStatisticsException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    final failure = switch ((status, code)) {
      (401, _) ||
      (_, 'NO_AUTENTICADO') => AppointmentStatisticsFailure.unauthenticated,
      (403, _) ||
      (_, 'ACCESO_DENEGADO') => AppointmentStatisticsFailure.forbidden,
      (400, 'VALIDACION') => AppointmentStatisticsFailure.validation,
      _ => AppointmentStatisticsFailure.other,
    };
    return AppointmentStatisticsException(
      failure,
      ApiException.fromDio(error).message,
    );
  }
}
