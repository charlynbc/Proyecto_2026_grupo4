import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../../usuarios/models/new_user.dart';
import '../models/doctor_shift.dart';
import '../models/doctor_shift_number.dart';
import 'doctor_shift_repository.dart';

class ApiDoctorShiftRepository implements DoctorShiftRepository {
  ApiDoctorShiftRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<DoctorShift>> getDoctorShifts({required DateTime date}) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiRoutes.doctorShifts,
          queryParameters: {'fecha': formatApiDate(date)},
        );
        final items = (response.data?['items'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        return [
          for (final item in items) DoctorShift.fromJson(item),
        ];
      });

  @override
  Future<DoctorShiftNumbersResponse> getDoctorShiftNumbers({
    required int shiftId,
    bool? llegada,
    String? orden,
    String? sentido,
  }) => _request(() async {
    final queryParameters = <String, dynamic>{};
    if (llegada != null) queryParameters['llegada'] = llegada;
    if (orden != null) queryParameters['orden'] = orden;
    if (sentido != null) queryParameters['sentido'] = sentido;

    final response = await _dio.get<Map<String, dynamic>>(
      ApiRoutes.doctorShiftNumbers(shiftId),
      queryParameters: queryParameters,
    );
    final payload = response.data ?? const <String, dynamic>{};
    return DoctorShiftNumbersResponse.fromJson(payload);
  });

  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw _mapError(e);
    } on TypeError {
      throw const ApiException();
    } on FormatException {
      throw const ApiException();
    }
  }

  ApiException _mapError(DioException e) {
    final error = ApiException.fromDio(e);
    return switch (apiCodeOf(e)) {
      'VALIDACION' => DoctorShiftValidationException(error.message),
      'TOKEN_INVALIDO' => DoctorShiftUnauthorizedException(error.message),
      'NO_ENCONTRADO' => DoctorShiftNotFoundException(error.message),
      _ => error,
    };
  }
}
