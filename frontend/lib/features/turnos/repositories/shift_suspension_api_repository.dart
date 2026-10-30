import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/suspension_filter.dart';
import '../models/suspension_preview.dart';
import '../models/suspension_result.dart';
import 'shift_repository.dart';
import 'shift_suspension_repository.dart';

/// Implementación real de [ShiftSuspensionRepository] (contrato #23 y #24). Los
/// errores se distinguen por `code`, nunca por el texto del mensaje.
///
/// Una respuesta mal formada (un campo que falta o con otro tipo, un cuerpo
/// vacío) se vuelve el error genérico: nunca se rellena con un valor por
/// defecto.
class ApiShiftSuspensionRepository implements ShiftSuspensionRepository {
  ApiShiftSuspensionRepository(this._dio);

  final Dio _dio;

  @override
  Future<SuspensionPreview> preview(List<int> ids) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiRoutes.shiftSuspensionsPreview,
      data: {'ids': ids},
    );
    return SuspensionPreview.fromJson(_body(response));
  });

  @override
  Future<SuspensionResult> suspend({
    required SuspensionFilter filter,
    required List<int> ids,
    String? observation,
    required int confirmedCount,
  }) => _request(() async {
    final trimmed = observation?.trim();
    final response = await _dio.post<Map<String, dynamic>>(
      ApiRoutes.shiftSuspensions,
      data: {
        'filtro': filter.toJson(),
        'ids': ids,
        if (trimmed != null && trimmed.isNotEmpty) 'observacion': trimmed,
        'cantidadConfirmada': confirmedCount,
      },
    );
    return SuspensionResult.fromJson(_body(response));
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
      'TURNO_NO_SUSPENDIBLE' => ShiftNotSuspendableException(error.message),
      'CONFIRMACION_DESACTUALIZADA' => StaleSuspensionConfirmationException(
        error.message,
      ),
      _ => error,
    };
  }
}
