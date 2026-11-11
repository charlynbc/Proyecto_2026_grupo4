import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/specialty.dart';
import 'specialty_correction_repository.dart';

/// Implementación real de [SpecialtyCorrectionRepository] (contrato, fila 59).
/// Una respuesta mal formada se vuelve el error genérico.
class ApiSpecialtyCorrectionRepository
    implements SpecialtyCorrectionRepository {
  ApiSpecialtyCorrectionRepository(this._dio);

  final Dio _dio;

  @override
  Future<Specialty> correct(
    int id, {
    String? name,
    bool? requiresReferral,
  }) async {
    if (id <= 0) {
      throw const SpecialtyCorrectionException(
        SpecialtyCorrectionFailure.notFound,
        'No se encontró la especialidad.',
      );
    }
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        ApiRoutes.specialty(id),
        data: {'nombre': ?name, 'requierePase': ?requiresReferral},
      );
      return Specialty.fromJson(
        response.data ?? (throw const FormatException()),
      );
    } on DioException catch (e) {
      throw _mapError(e);
    } on FormatException {
      throw const SpecialtyCorrectionException(
        SpecialtyCorrectionFailure.other,
      );
    } on TypeError {
      throw const SpecialtyCorrectionException(
        SpecialtyCorrectionFailure.other,
      );
    }
  }

  /// Distingue los casos por su `code`; el mensaje es el del servidor.
  SpecialtyCorrectionException _mapError(DioException e) {
    final failure = switch (apiCodeOf(e)) {
      'ESPECIALIDAD_NO_ENCONTRADA' => SpecialtyCorrectionFailure.notFound,
      'ESPECIALIDAD_DUPLICADA' => SpecialtyCorrectionFailure.duplicate,
      'VALIDACION' => SpecialtyCorrectionFailure.validation,
      _ => SpecialtyCorrectionFailure.other,
    };
    return SpecialtyCorrectionException(
      failure,
      ApiException.fromDio(e).message,
    );
  }
}
