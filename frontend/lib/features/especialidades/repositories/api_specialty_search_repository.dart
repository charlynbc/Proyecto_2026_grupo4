import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/specialty.dart';
import '../models/specialty_filters.dart';
import 'specialty_search_repository.dart';

/// Consulta especialidades con filtros mediante el Dio recibido.
class ApiSpecialtySearchRepository implements SpecialtySearchRepository {
  ApiSpecialtySearchRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) async {
    final Map<String, dynamic> parameters;
    try {
      parameters = filters.toQueryParameters();
    } on ArgumentError {
      throw const SpecialtySearchException(
        SpecialtySearchFailure.validation,
        'El nombre no puede superar los 120 caracteres.',
      );
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.specialties,
        queryParameters: parameters,
      );
      final items = response.data?['items'];
      if (items is! List) throw const ApiException();

      return [
        for (final item in items)
          Specialty.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  SpecialtySearchException _mapError(DioException error) {
    final failure = switch (apiCodeOf(error)) {
      'VALIDACION' => SpecialtySearchFailure.validation,
      'NO_AUTENTICADO' => SpecialtySearchFailure.unauthenticated,
      'ACCESO_DENEGADO' => SpecialtySearchFailure.forbidden,
      _ => SpecialtySearchFailure.other,
    };
    return SpecialtySearchException(
      failure,
      ApiException.fromDio(error).message,
    );
  }
}
