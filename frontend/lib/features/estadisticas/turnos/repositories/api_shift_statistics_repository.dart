import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_routes.dart';
import '../../../agenda/models/agenda_time.dart';
import '../models/shift_utilization.dart';
import 'shift_statistics_repository.dart';

class ApiShiftStatisticsRepository implements ShiftStatisticsRepository {
  ApiShiftStatisticsRepository(this._dio);

  final Dio _dio;

  @override
  Future<ShiftUtilization> utilization({DateTime? from, DateTime? to}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.statsShifts,
        queryParameters: {
          if (from != null) 'desde': formatApiDate(from),
          if (to != null) 'hasta': formatApiDate(to),
        },
      );
      return ShiftUtilization.fromJson(
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

  ShiftStatisticsException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    final failure = switch ((status, code)) {
      (401, _) ||
      (_, 'NO_AUTENTICADO') => ShiftStatisticsFailure.unauthenticated,
      (403, _) || (_, 'ACCESO_DENEGADO') => ShiftStatisticsFailure.forbidden,
      (400, 'VALIDACION') => ShiftStatisticsFailure.validation,
      _ => ShiftStatisticsFailure.other,
    };
    return ShiftStatisticsException(
      failure,
      ApiException.fromDio(error).message,
    );
  }
}
