import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/schedule_filters.dart';
import '../models/schedule_page.dart';
import 'schedule_repository.dart';

/// Implementación real de [ScheduleRepository] (contrato #28). Los errores se
/// distinguen por `code`, nunca por el texto del mensaje.
///
/// Una respuesta mal formada (un campo que falta o con otro tipo, una fecha, un
/// estado o un instante inesperados, un cuerpo vacío) se vuelve el error
/// genérico: nunca se rellena con un valor por defecto.
class ApiScheduleRepository implements ScheduleRepository {
  ApiScheduleRepository(this._dio);

  final Dio _dio;

  @override
  Future<SchedulePage> search(ScheduleFilters filters) => _request(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiRoutes.schedules,
      queryParameters: filters.toQueryParameters(),
    );
    return SchedulePage.fromJson(_body(response));
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
      'VALIDACION' => ScheduleValidationException(error.message),
      _ => error,
    };
  }
}
