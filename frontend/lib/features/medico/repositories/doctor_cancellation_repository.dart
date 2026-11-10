import '../../../core/network/api_exception.dart';
import '../models/doctor_cancellation_result.dart';
import '../models/doctor_shift_cancellation_result.dart';

/// Cancelación de una consulta del médico autenticado (RF-27).
abstract class DoctorCancellationRepository {
  Future<DoctorShiftCancellationResult> cancelShift(int shiftId, String reason);

  /// Cancela la consulta [appointmentId] con el [reason] ya recortado.
  Future<DoctorCancellationResult> cancelAppointment(
    int appointmentId,
    String reason,
  );
}

String cancelShiftMessage(
  DoctorCancellationFailure failure,
) => switch (failure) {
  DoctorCancellationFailure.validation =>
    'Revisá el motivo: es obligatorio y no puede superar los 1000 caracteres.',
  DoctorCancellationFailure.forbidden =>
    'Tu cuenta no tiene permiso para cancelar turnos.',
  DoctorCancellationFailure.conflictOfInterest => 'Tenés una consulta propia agendada en este turno, así que no podés cancelarlo completo. Pedile a la administración que suspenda la fecha.',
  DoctorCancellationFailure.notFound =>
    'No encontramos este turno entre los tuyos. Se actualizó la lista.',
  DoctorCancellationFailure.shiftNotCancellable => 'Este turno ya no se puede cancelar: ya está suspendido o su fecha pasó. Se actualizó la lista.',
  DoctorCancellationFailure.outsideWindow => 'No se puede cancelar el turno completo porque hay consultas a menos de 2 horas de su hora. No se canceló ninguna. Si es un imprevisto, coordinalo con la administración.',
  DoctorCancellationFailure.notScheduled => kApiGenericMessage,
};

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

/// Una cancelación rechazada por un código conocido. El [message] es el texto
/// propio de ese caso. Un 500 o un código sin rama no usa esta clase: es un
/// [ApiException] y sí muestra el texto del servidor.
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
    DoctorCancellationFailure.conflictOfInterest =>
      'No podés cancelar una consulta en la que vos sos el socio. '
          'Pedile a otra persona que lo haga.',
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
