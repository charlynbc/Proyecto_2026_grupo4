import '../../../core/network/api_exception.dart';
import '../models/doctor_appointment_result.dart';

/// Resultado de la consulta y pases del médico autenticado (RF-23 y RF-24).
abstract class DoctorResultRepository {
  /// Registra el resultado definitivo de la consulta [appointmentId]. La
  /// atención y sus pases se guardan juntos o no se guarda nada.
  Future<AppointmentResult> register(
    int appointmentId,
    AppointmentResultRequest request,
  );
}

/// Un dato que no cumple las reglas (`VALIDACION`, 400).
class ResultValidationException extends ApiException {
  const ResultValidationException([
    super.message =
        'Revisá los datos cargados. Si el paciente fue atendido, la afección '
        'es obligatoria. Cada pase necesita una especialidad distinta y una '
        'vigencia de 1 a 365 días.',
  ]);

  String get code => 'VALIDACION';
}

/// El médico es el propio paciente de la consulta (`CONFLICTO_DE_INTERES`,
/// 403).
class ConflictOfInterestException extends ApiException {
  const ConflictOfInterestException([
    super.message =
        'No podés registrar el resultado de tu propia consulta. Pedile a otro '
        'médico que la atienda.',
  ]);

  String get code => 'CONFLICTO_DE_INTERES';
}

/// La consulta no existe o no es del médico (`NO_ENCONTRADO`, 404).
class ResultAppointmentNotFoundException extends ApiException {
  const ResultAppointmentNotFoundException([
    super.message =
        'No encontramos esta consulta entre las tuyas. Volvé a tus turnos y '
        'elegí otra.',
  ]);

  String get code => 'NO_ENCONTRADO';
}

/// La consulta ya no está agendada: tiene resultado o se canceló
/// (`CONSULTA_NO_AGENDADA`, 409).
class AppointmentNotScheduledException extends ApiException {
  const AppointmentNotScheduledException([
    super.message =
        'Esta consulta ya tiene un resultado registrado o fue cancelada, así '
        'que no se puede cargar de nuevo. Volvé a tus turnos para ver cómo '
        'quedó.',
  ]);

  String get code => 'CONSULTA_NO_AGENDADA';
}

/// La consulta no es de hoy (`CONSULTA_NO_ES_DE_HOY`, 409).
class AppointmentNotTodayException extends ApiException {
  const AppointmentNotTodayException([
    super.message =
        'El resultado solo se puede registrar el mismo día de la consulta. '
        'Volvé a tus turnos y elegí una consulta de hoy.',
  ]);

  String get code => 'CONSULTA_NO_ES_DE_HOY';
}

/// El paciente no avisó su llegada hoy (`SIN_AVISO_LLEGADA`, 409).
class NoArrivalNoticeException extends ApiException {
  const NoArrivalNoticeException([
    super.message =
        'El paciente todavía no avisó que llegó, así que no se puede '
        'registrar el resultado. Esperá su aviso de llegada e intentá de '
        'nuevo.',
  ]);

  String get code => 'SIN_AVISO_LLEGADA';
}

/// El paciente ya tiene un pase vigente o una consulta pendiente en alguna de
/// las especialidades elegidas (`PASE_DUPLICADO`, 409).
class DuplicateReferralException extends ApiException {
  const DuplicateReferralException([
    super.message =
        'El paciente ya tiene un pase vigente o una consulta pendiente en '
        'una de las especialidades elegidas. Quitá ese pase e intentá de '
        'nuevo. No se guardó nada.',
  ]);

  String get code => 'PASE_DUPLICADO';
}
