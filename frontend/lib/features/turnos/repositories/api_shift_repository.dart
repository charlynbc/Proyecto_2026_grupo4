import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/doctor.dart';
import '../models/new_weekly_shift.dart';
import '../models/shift_filters.dart';
import '../models/shift_page.dart';
import '../models/weekly_shift.dart';
import 'shift_repository.dart';

/// Implementación real de [ShiftRepository] (contrato #10, #13, #14 y #15). Los
/// errores se distinguen por `code`, nunca por el texto del mensaje.
///
/// Una respuesta mal formada (un campo que falta o con otro tipo, una fecha o
/// un estado desconocidos, un cuerpo vacío) se vuelve el error genérico: nunca
/// se rellena con un valor por defecto.
class ApiShiftRepository implements ShiftRepository {
  ApiShiftRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) => _request(() async {
    final response = await _dio.get<Object>(
      ApiRoutes.doctors,
      queryParameters: {'especialidadId': ?specialtyId},
    );
    // El backend devuelve una lista JSON; se acepta también `{"items": [...]}`.
    final body = response.data;
    final items = switch (body) {
      List<dynamic>() => body,
      Map<String, dynamic>() => body['items'] as List<dynamic>,
      _ => throw const ApiException(),
    };
    return [
      for (final item in items) Doctor.fromJson(item as Map<String, dynamic>),
    ];
  });

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiRoutes.weeklyShifts,
          data: data.toJson(),
        );
        return WeeklyShift.fromJson(_body(response));
      });

  @override
  Future<WeeklyShift> getWeeklyShift(int id) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiRoutes.weeklyShift(id),
    );
    return WeeklyShift.fromJson(_body(response));
  });

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiRoutes.shifts,
      queryParameters: filters.toQueryParameters(),
    );
    return ShiftPage.fromJson(_body(response));
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
      'ESPECIALIDAD_NO_DEL_MEDICO' => SpecialtyNotOfDoctorException(
        error.message,
      ),
      'MEDICO_INACTIVO' => InactiveDoctorException(error.message),
      'NO_ENCONTRADO' => ShiftNotFoundException(error.message),
      'SOLAPAMIENTO_TURNO' => OverlappingShiftException(error.message),
      _ => error,
    };
  }
}
