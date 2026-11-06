import '../../../core/network/api_exception.dart';
import '../models/cancellation_result.dart';

abstract class AppointmentCancellationRepository {
  Future<CancellationResult> cancel(int id);
}

enum CancellationFailure {
  /// `NO_ENCONTRADO` (404): la consulta no existe.
  notFound,

  /// `CONSULTA_NO_AGENDADA` (409): la consulta no está agendada.
  notScheduled,

  /// `CANCELACION_FUERA_DE_PLAZO` (409): pasó el plazo de cancelación.
  outsideWindow,

  /// `LLEGADA_YA_REGISTRADA` (409): la llegada de la consulta ya fue registrada.
  alreadyArrived,

  /// `VALIDACION` (400): los datos enviados no son válidos.
  validation,

  /// `NO_AUTENTICADO` (401): la sesión no es válida.
  unauthenticated,

  /// `ACCESO_DENEGADO` (403): el usuario no puede cancelar la consulta.
  forbidden,

  /// Sin respuesta del servidor o un `code` que no se conoce.
  other,
}

class CancellationException extends ApiException {
  const CancellationException(this.failure, [super.message]);

  final CancellationFailure failure;
}
