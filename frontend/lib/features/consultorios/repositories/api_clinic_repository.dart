import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/clinic.dart';
import 'clinic_repository.dart';

/// Implementación real de [ClinicRepository] (contrato #8 y #9).
class ApiClinicRepository implements ClinicRepository {
  ApiClinicRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Clinic>> list() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(ApiRoutes.clinics);
      return [
        for (final item in response.data!['items'] as List<dynamic>)
          Clinic.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<Clinic> create({
    required String name,
    required String location,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.clinics,
        data: {'nombre': name, 'ubicacion': location},
      );
      return Clinic.fromJson(response.data!);
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (apiCodeOf(e) == 'CONSULTORIO_DUPLICADO') {
        throw DuplicateClinicException(error.message);
      }
      throw error;
    }
  }
}
