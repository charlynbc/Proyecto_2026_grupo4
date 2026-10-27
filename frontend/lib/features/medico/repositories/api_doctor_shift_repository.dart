import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/doctor_shift.dart';
import 'doctor_shift_repository.dart';

/// Implementación real de [DoctorShiftRepository]. Una respuesta mal formada
/// se vuelve el error genérico: no se rellena nada.
class ApiDoctorShiftRepository implements DoctorShiftRepository {
  ApiDoctorShiftRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<DoctorShift>> listShifts(String date) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.doctorShifts,
        queryParameters: {'fecha': date},
      );
      final items = (response.data ?? (throw const ApiException()))['items'];
      return [
        for (final item in items as List<dynamic>)
          DoctorShift.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<DoctorShiftNumbers> listNumbers(
    int shiftId, {
    bool? arrived,
    DoctorNumbersOrder order = DoctorNumbersOrder.time,
    bool ascending = true,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.doctorShiftNumbers(shiftId),
        queryParameters: {
          'llegada': ?arrived,
          'orden': order.apiValue,
          'sentido': ascending ? 'asc' : 'desc',
        },
      );
      return DoctorShiftNumbers.fromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }
}
