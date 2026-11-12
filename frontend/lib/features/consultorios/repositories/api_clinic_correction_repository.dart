import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/clinic.dart';
import 'clinic_correction_repository.dart';

class ApiClinicCorrectionRepository implements ClinicCorrectionRepository {
  ApiClinicCorrectionRepository(this._dio);

  final Dio _dio;

  @override
  Future<Clinic> correct(int id, {String? name, String? location}) async {
    if (id <= 0) {
      throw const ClinicCorrectionException(ClinicCorrectionFailure.notFound);
    }

    final data = <String, String>{'nombre': ?name, 'ubicacion': ?location};
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiRoutes.clinic(id),
        data: data,
      );
      return Clinic.fromJson(response.data ?? (throw const ApiException()));
    } on DioException catch (error) {
      final failure = switch (apiCodeOf(error)) {
        'CONSULTORIO_NO_ENCONTRADO' => ClinicCorrectionFailure.notFound,
        'CONSULTORIO_DUPLICADO' => ClinicCorrectionFailure.duplicate,
        'VALIDACION' => ClinicCorrectionFailure.validation,
        _ => ClinicCorrectionFailure.other,
      };
      throw ClinicCorrectionException(
        failure,
        ApiException.fromDio(error).message,
      );
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }
}
