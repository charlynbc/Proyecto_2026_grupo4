import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/staff_cancellation_result.dart';
import 'staff_cancellation_repository.dart';

class ApiStaffCancellationRepository implements StaffCancellationRepository {
  ApiStaffCancellationRepository(this._dio);

  final Dio _dio;

  @override
  Future<StaffCancellationResult> cancel(int id) => _request(() async {
    if (id <= 0) {
      throw const StaffCancellationException(
        StaffCancellationFailure.validation,
        kApiGenericMessage,
      );
    }
    final response = await _dio.post<Map<String, dynamic>>(
      ApiRoutes.staffAppointmentCancel(id),
    );
    final body = response.data ?? _throwMalformed();
    final appointmentId = body['consultaId'] as int;
    final status = body['estado'] as String;
    final cancelledAt = DateTime.parse(body['canceladaEn'] as String).toUtc();
    final referralReturned = body['paseDevuelto'] as bool;
    if (status != 'CANCELADA_SOCIO') {
      throw const FormatException();
    }
    return StaffCancellationResult(
      appointmentId: appointmentId,
      status: status,
      cancelledAt: cancelledAt,
      referralReturned: referralReturned,
    );
  });

  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on StaffCancellationException {
      rethrow;
    } on DioException catch (error) {
      throw _mapError(error);
    } on FormatException {
      throw const StaffCancellationException(
        StaffCancellationFailure.other,
        kApiGenericMessage,
      );
    } on TypeError {
      throw const StaffCancellationException(
        StaffCancellationFailure.other,
        kApiGenericMessage,
      );
    }
  }

  Never _throwMalformed() {
    throw const FormatException();
  }

  StaffCancellationException _mapError(DioException error) {
    if (error.response == null) {
      return const StaffCancellationException(
        StaffCancellationFailure.other,
        kApiGenericMessage,
      );
    }

    final data = error.response?.data;
    final message = data is Map ? data['message'] : null;
    final serverMessage = message is String && message.isNotEmpty
        ? message
        : kApiGenericMessage;
    final code = data is Map ? data['code'] : null;
    final stringCode = code is String ? code : null;
    final status = error.response?.statusCode;
    final failure = switch (status) {
      401 => StaffCancellationFailure.unauthenticated,
      403 when stringCode == 'CONFLICTO_INTERES' =>
        StaffCancellationFailure.conflictOfInterest,
      403 => StaffCancellationFailure.forbidden,
      404 => StaffCancellationFailure.notFound,
      409 when stringCode == 'CONSULTA_NO_AGENDADA' =>
        StaffCancellationFailure.notScheduled,
      409 when stringCode == 'CANCELACION_FUERA_DE_PLAZO' =>
        StaffCancellationFailure.outsideWindow,
      400 => StaffCancellationFailure.validation,
      _ => StaffCancellationFailure.other,
    };
    return StaffCancellationException(failure, serverMessage);
  }
}
