import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/specialty.dart';
import 'specialty_repository.dart';

/// Implementación real de [SpecialtyRepository] (contrato #6 y #7).
class ApiSpecialtyRepository implements SpecialtyRepository {
  ApiSpecialtyRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Specialty>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.specialties,
      );
      return [
        for (final item in response.data!['items'] as List<dynamic>)
          Specialty.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Specialty> create({
    required String name,
    required bool requiresReferral,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.specialties,
        data: {'nombre': name, 'requierePase': requiresReferral},
      );
      return Specialty.fromJson(response.data!);
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (apiCodeOf(e) == 'ESPECIALIDAD_DUPLICADA') {
        throw DuplicateSpecialtyException(error.message);
      }
      throw error;
    }
  }
}
