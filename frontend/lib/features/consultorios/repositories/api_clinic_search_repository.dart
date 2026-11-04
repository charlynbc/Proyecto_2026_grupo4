import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/clinic.dart';
import '../models/clinic_filters.dart';
import 'clinic_search_repository.dart';

/// Consulta consultorios con filtros mediante el Dio recibido.
class ApiClinicSearchRepository implements ClinicSearchRepository {
  ApiClinicSearchRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Clinic>> search(ClinicFilters filters) async {
    final Map<String, dynamic> parameters;
    try {
      parameters = filters.toQueryParameters();
    } on ArgumentError catch (error) {
      final message = error.message;
      throw ClinicSearchException(
        ClinicSearchFailure.validation,
        message is String && message.isNotEmpty ? message : kApiGenericMessage,
      );
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.clinics,
        queryParameters: parameters,
      );
      final items = response.data?['items'];
      if (items is! List) throw const ApiException();

      return [
        for (final item in items) Clinic.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  ClinicSearchException _mapError(DioException error) {
    final failure = switch (apiCodeOf(error)) {
      'VALIDACION' => ClinicSearchFailure.validation,
      'NO_AUTENTICADO' => ClinicSearchFailure.unauthenticated,
      'ACCESO_DENEGADO' => ClinicSearchFailure.forbidden,
      _ => ClinicSearchFailure.other,
    };
    return ClinicSearchException(failure, ApiException.fromDio(error).message);
  }
}
