import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../../agenda/models/appointment.dart';
import '../models/arrival.dart';
import 'arrival_repository.dart';

/// Implementación real de [ArrivalRepository]. Los errores se distinguen por
/// `code`, nunca por el texto del mensaje. Mientras el contrato y el backend
/// no unifiquen los códigos, se aceptan los dos nombres de cada caso.
///
/// Una respuesta mal formada se vuelve el error genérico: nunca se rellena con
/// un valor por defecto.
class ApiArrivalRepository implements ArrivalRepository {
  ApiArrivalRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<Appointment>> listTodayAppointments(String ci) =>
      _request(() async {
        final response = await _dio.get<Map<String, dynamic>>(
          ApiRoutes.arrivalsTodayAppointments,
          queryParameters: {'ci': normalizeCi(ci)},
        );
        return [
          for (final item in _body(response)['items'] as List<dynamic>)
            Appointment.fromJson(item as Map<String, dynamic>),
        ];
      });

  @override
  Future<ArrivalResult> registerArrival(String ci) => _request(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiRoutes.arrivals,
      data: {'ci': normalizeCi(ci)},
    );
    return ArrivalResult(
      arrival: Arrival.fromJson(_body(response)),
      // 201: se creó ahora. 200: ya existía y vuelve el aviso original.
      created: response.statusCode == 201,
    );
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
      'VALIDACION' => ArrivalValidationException(error.message),
      'NO_ENCONTRADO' => const MemberNotFoundException(),
      'CONFLICTO_INTERES' ||
      'CONFLICTO_DE_INTERES' => const ConflictOfInterestException(),
      'SIN_CONSULTAS_AGENDADAS' ||
      'SIN_CONSULTAS_HOY' => const NoAppointmentsTodayException(),
      _ => error,
    };
  }
}
