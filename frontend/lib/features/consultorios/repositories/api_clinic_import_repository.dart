import 'package:dio/dio.dart';

import '../../../core/files/csv_upload.dart';
import '../../../core/files/picked_csv_file.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/clinic_import.dart';
import 'clinic_import_repository.dart';

/// Implementación real de [ClinicImportRepository] (contrato #56 y #57). El
/// archivo viaja como `multipart/form-data`, en el campo `archivo`. Una
/// respuesta mal formada se vuelve el error genérico: no se rellena nada.
class ApiClinicImportRepository implements ClinicImportRepository {
  ApiClinicImportRepository(this._dio);

  final Dio _dio;

  @override
  Future<ClinicImportPreview> preview(PickedCsvFile file) =>
      _post(ApiRoutes.clinicsImportPreview, file, ClinicImportPreview.fromJson);

  @override
  Future<ClinicImportResult> confirm(PickedCsvFile file) =>
      _post(ApiRoutes.clinicsImportConfirm, file, ClinicImportResult.fromJson);

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
