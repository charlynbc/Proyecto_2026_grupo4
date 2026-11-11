import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/weekly_shift.dart';
import '../models/clinic_change_preview.dart';
import 'shift_repository.dart';
import 'weekly_shift_clinic_repository.dart';

/// PATCH del consultorio de una configuración semanal (fila 51).
///
/// Los errores se distinguen por `code`. Una respuesta mal formada se vuelve
/// el error genérico.
class ApiWeeklyShiftClinicRepository implements WeeklyShiftClinicRepository {
  ApiWeeklyShiftClinicRepository(this._dio);

  final Dio _dio;

  @override
  Future<ClinicChangePreview> previewClinicChange(
    int weeklyShiftId,
    int clinicId,
  ) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiRoutes.weeklyShiftClinicPreview(weeklyShiftId),
      data: {'consultorioId': clinicId},
    );
    return ClinicChangePreview.fromJson(_body(response));
  });

  @override
  Future<WeeklyShift> changeClinic(
    int weeklyShiftId,
    int clinicId, {
    List<int>? turnoIds,
    bool confirmarConConsultas = false,
  }) => _request(() async {
        final response = await _dio.patch<Map<String, dynamic>>(
          ApiRoutes.weeklyShift(weeklyShiftId),
          data: {
            'consultorioId': clinicId,
            if (turnoIds != null) 'turnoIds': turnoIds,
            if (confirmarConConsultas) 'confirmarConConsultas': true,
          },
        );
        return WeeklyShift.fromJson(_body(response));
      });

  /// Corre el pedido y traduce sus fallas: las de la red o del servidor por su
  /// `code`, y una respuesta mal formada como el error genérico.
  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapError(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  Map<String, dynamic> _body(Response<Map<String, dynamic>> response) =>
      response.data ?? (throw const ApiException());

  ApiException _mapError(DioException e) {
    final error = ApiException.fromDio(e);
    return switch (apiCodeOf(e)) {
      'VALIDACION' => ShiftValidationException(error.message),
      'NO_ENCONTRADO' => ShiftNotFoundException(error.message),
      'TURNO_NO_MODIFICABLE' => ShiftNotModifiableException(error.message),
      'SOLAPAMIENTO_TURNO' => OverlappingShiftException(error.message),
      _ => error,
    };
  }
}
