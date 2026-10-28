import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/shift_date_format.dart';
import 'shift_repository.dart';
import 'shift_reinstatement_repository.dart';

/// Implementación real de [ShiftReinstatementRepository] (contrato #25).
/// Los errores se distinguen por `code`, nunca por el texto del mensaje.
class ApiShiftReinstatementRepository implements ShiftReinstatementRepository {
  ApiShiftReinstatementRepository(this._dio);

  final Dio _dio;

  @override
  Future<ShiftReinstatementResult> reinstate(ShiftReinstatement request) =>
      _request(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiRoutes.shiftReinstatements,
          data: {
            'filtro': {
              'medicoId': request.doctorId,
              'especialidadId': request.specialtyId,
              'fechaDesde': formatDateKey(request.fromDate),
              'fechaHasta': formatDateKey(request.toDate),
            },
            'ids': request.shiftIds,
          },
        );
        final body = response.data ?? (throw const ApiException());
        final turnos = body['turnos'] as List<dynamic>;
        return ShiftReinstatementResult(
          shifts: [
            for (final item in turnos)
              ReinstatedShift(
                id: (item as Map<String, dynamic>)['turnoId'] as int,
                date: parseDateKey(item['fecha'] as String),
              ),
          ],
          cancelledAppointments: body['consultasCanceladas'] as int,
        );
      });

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
    final apiError = ApiException.fromDio(error);
    return switch (apiCodeOf(error)) {
      'SOLAPAMIENTO_TURNO' => OverlappingShiftException(apiError.message),
      'MEDICO_INACTIVO' => InactiveDoctorException(apiError.message),
      'TURNO_NO_REHABILITABLE' => ShiftNotReinstatableException(
        apiError.message,
      ),
      _ => apiError,
    };
  }
}
