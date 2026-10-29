import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/medical_history_entry.dart';
import '../models/medical_history_query.dart';
import 'medical_history_repository.dart';

/// Consulta la historia clínica mediante el Dio compartido de la aplicación.
class ApiMedicalHistoryRepository implements MedicalHistoryRepository {
  ApiMedicalHistoryRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<MedicalHistoryEntry>> list(MedicalHistoryQuery query) =>
      _request(() async {
        final response = await _dio.get<List<dynamic>>(
          ApiRoutes.medicalHistory,
          queryParameters: query.toQueryParameters(),
        );
        final items = response.data ?? (throw const ApiException());
        return [
          for (final item in items)
            MedicalHistoryEntry.fromJson(item as Map<String, dynamic>),
        ];
      });

  @override
  Future<MedicalHistoryEntry> get(int id) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiRoutes.medicalHistoryEntry(id),
    );
    return MedicalHistoryEntry.fromJson(
      response.data ?? (throw const ApiException()),
    );
  });

  /// Traduce los errores de la API y las respuestas con formato incorrecto.
  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  ApiException _mapError(DioException error) {
    return switch (apiCodeOf(error)) {
      'HISTORIA_NO_ENCONTRADA' => const MedicalHistoryNotFoundException(),
      _ => ApiException.fromDio(error),
    };
  }
}
