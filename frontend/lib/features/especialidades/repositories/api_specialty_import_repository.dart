import 'package:dio/dio.dart';

import '../../../core/files/csv_upload.dart';
import '../../../core/files/picked_csv_file.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/specialty_import.dart';
import 'specialty_import_repository.dart';

/// Implementación real de [SpecialtyImportRepository] (contrato #52 y #53).
/// El archivo viaja como `multipart/form-data`, en el campo `archivo`. Una
/// respuesta mal formada se vuelve el error genérico: no se rellena nada.
class ApiSpecialtyImportRepository implements SpecialtyImportRepository {
  ApiSpecialtyImportRepository(this._dio);

  final Dio _dio;

  @override
  Future<SpecialtyImportPreview> preview(PickedCsvFile file) => _post(
    ApiRoutes.specialtiesImportPreview,
    file,
    SpecialtyImportPreview.fromJson,
  );

  @override
  Future<SpecialtyImportResult> confirm(PickedCsvFile file) => _post(
    ApiRoutes.specialtiesImportConfirm,
    file,
    SpecialtyImportResult.fromJson,
  );

  Future<T> _post<T>(
    String route,
    PickedCsvFile file,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        route,
        data: buildImportFormData(file),
      );
      return parse(response.data ?? (throw const ApiException()));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }
}
