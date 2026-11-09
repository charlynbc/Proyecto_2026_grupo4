import '../../../core/network/api_exception.dart';
import '../models/doctor_cancellation_result.dart';

/// Cancelación de una consulta del médico autenticado (RF-27).
abstract class DoctorCancellationRepository {
  /// Cancela la consulta [appointmentId] con el [reason] ya recortado.
  Future<DoctorCancellationResult> cancelAppointment(
    int appointmentId,
    String reason,
  );
}

/// Por qué no se pudo cancelar. [shiftNotCancellable] lo usa la cancelación
/// del turno completo.
enum DoctorCancellationFailure {
  validation,
  forbidden,
  conflictOfInterest,
  notFound,
  notScheduled,
  outsideWindow,
  shiftNotCancellable,
}

/// Una cancelación rechazada. El [message] es propio: el texto del servidor
/// no se muestra.
class DoctorCancellationException extends ApiException {
  const DoctorCancellationException(this.failure, String message)
    : super(message);

  final DoctorCancellationFailure failure;
}

/// El texto que ve el médico para cada [failure].
String cancelAppointmentMessage(DoctorCancellationFailure failure) {
  return switch (failure) {
    DoctorCancellationFailure.validation => 'Revisá el motivo: es obligatorio y no puede superar los 1000 caracteres.',
    DoctorCancellationFailure.forbidden =>
      'Tu cuenta no tiene permiso para cancelar consultas.',
    DoctorCancellationFailure.conflictOfInterest => 'No podés cancelar tu propia consulta. Pedile a otro empleado que lo haga.',
    DoctorCancellationFailure.notFound =>
      'No encontramos esta consulta entre las tuyas. Se actualizó la lista.',
    DoctorCancellationFailure.notScheduled =>
      'Esta consulta ya no está agendada, así que no se puede cancelar. '
          'Se actualizó la lista.',
    DoctorCancellationFailure.outsideWindow =>
      'Ya no se puede cancelar: faltan menos de 2 horas para la hora del '
          'número. Si es un imprevisto, coordinalo con la administración.',
    DoctorCancellationFailure.shiftNotCancellable => kApiGenericMessage,
  };
}
