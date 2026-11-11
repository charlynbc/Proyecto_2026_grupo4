import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_routes.dart';
import '../../../agenda/models/agenda_time.dart';
import '../models/absence_statistics.dart';
import 'absence_statistics_repository.dart';

class ApiAbsenceStatisticsRepository implements AbsenceStatisticsRepository {
  ApiAbsenceStatisticsRepository(this._dio);

  final Dio _dio;

  @override
  Future<AbsenceStatistics> statistics({
    DateTime? from,
    DateTime? to,
    required AbsenceGrouping grouping,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.statsAbsences,
        queryParameters: {
          if (from != null) 'desde': formatApiDate(from),
          if (to != null) 'hasta': formatApiDate(to),
          'agruparPor': grouping.apiValue,
        },
      );
      return AbsenceStatistics.fromJson(
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

  AbsenceStatisticsException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    final failure = switch ((status, code)) {
      (401, _) ||
      (_, 'NO_AUTENTICADO') => AbsenceStatisticsFailure.unauthenticated,
      (403, _) || (_, 'ACCESO_DENEGADO') => AbsenceStatisticsFailure.forbidden,
      (400, 'VALIDACION') => AbsenceStatisticsFailure.validation,
      _ => AbsenceStatisticsFailure.other,
    };
    if (failure == AbsenceStatisticsFailure.forbidden) {
      return const AbsenceStatisticsException(
        AbsenceStatisticsFailure.forbidden,
        kAbsenceStatisticsForbiddenMessage,
      );
    }
    return AbsenceStatisticsException(
      failure,
      ApiException.fromDio(error).message,
    );
  }
}
