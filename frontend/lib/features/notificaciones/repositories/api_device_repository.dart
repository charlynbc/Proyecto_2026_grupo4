import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/device_registration.dart';
import 'device_repository.dart';

class ApiDeviceRepository implements DeviceRepository {
  ApiDeviceRepository(this._dio);

  final Dio _dio;

  @override
  Future<DeviceRegistration> register(String token) async {
    _requireToken(token);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.devices,
        data: {'token': token},
      );
      return DeviceRegistration.fromJson(
        response.data ?? (throw const ApiException()),
        created: response.statusCode == 201,
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
  Future<void> deactivate(String token) async {
    _requireToken(token);
    try {
      await _dio.post<void>(
        ApiRoutes.devicesDeactivate,
        data: {'token': token},
      );
    } on DioException catch (error) {
      throw _mapError(error);
    }
  }

  /// El servidor también lo valida; acá se evita un pedido que seguro falla.
  void _requireToken(String token) {
    if (token.trim().isEmpty) {
      throw const DeviceException(
        DeviceFailure.validation,
        'No pudimos identificar este dispositivo para las notificaciones.',
      );
    }
  }

  DeviceException _mapError(DioException error) {
    final message = ApiException.fromDio(error).message;
    final status = error.response?.statusCode;
    final failure = switch ((status, apiCodeOf(error))) {
      (_, 'VALIDACION') => DeviceFailure.validation,
      (_, 'NO_AUTENTICADO') => DeviceFailure.unauthenticated,
      (_, 'ACCESO_DENEGADO') => DeviceFailure.forbidden,
      (401, _) => DeviceFailure.unauthenticated,
      (403, _) => DeviceFailure.forbidden,
      _ => DeviceFailure.other,
    };
    return DeviceException(failure, message);
  }
}
