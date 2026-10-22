import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/appointment.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';
import 'appointment_history_repository.dart';

class ApiAppointmentHistoryRepository implements AppointmentHistoryRepository {
  ApiAppointmentHistoryRepository(this._dio);

  final Dio _dio;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.appointments,
        queryParameters: query.toQueryParameters(),
      );
      return AppointmentHistoryPage.fromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<Appointment> get(int id) async {
    if (id <= 0) {
      throw const AppointmentHistoryException(
        AppointmentHistoryFailure.notFound,
        'No se encontró la consulta.',
      );
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.appointment(id),
      );
      return Appointment.fromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  AppointmentHistoryException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final code = apiCodeOf(error);
    final failure = switch ((status, code)) {
      (401, _) ||
      (_, 'NO_AUTENTICADO') => AppointmentHistoryFailure.unauthenticated,
      (403, _) || (_, 'ACCESO_DENEGADO') => AppointmentHistoryFailure.forbidden,
      (404, _) || (_, 'NO_ENCONTRADO') => AppointmentHistoryFailure.notFound,
      _ => AppointmentHistoryFailure.other,
    };
    return AppointmentHistoryException(
      failure,
      ApiException.fromDio(error).message,
    );
  }
}
