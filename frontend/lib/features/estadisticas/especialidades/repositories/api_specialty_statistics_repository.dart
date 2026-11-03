import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_routes.dart';
import '../../../agenda/models/agenda_time.dart';
import '../models/specialty_demand.dart';
import 'specialty_statistics_repository.dart';

class ApiSpecialtyStatisticsRepository
    implements SpecialtyStatisticsRepository {
  ApiSpecialtyStatisticsRepository(this._dio);

  final Dio _dio;

  @override
  Future<SpecialtyDemand> demand({DateTime? from, DateTime? to}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.statsSpecialties,
        queryParameters: {
          if (from != null) 'desde': formatApiDate(from),
          if (to != null) 'hasta': formatApiDate(to),
        },
      );
      return SpecialtyDemand.fromJson(
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

  SpecialtyStatisticsException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    final failure = switch ((status, code)) {
      (401, _) ||
      (_, 'NO_AUTENTICADO') => SpecialtyStatisticsFailure.unauthenticated,
      (403, _) ||
      (_, 'ACCESO_DENEGADO') => SpecialtyStatisticsFailure.forbidden,
      (400, 'VALIDACION') => SpecialtyStatisticsFailure.validation,
      _ => SpecialtyStatisticsFailure.other,
    };
    return SpecialtyStatisticsException(
      failure,
      ApiException.fromDio(error).message,
    );
  }
}
