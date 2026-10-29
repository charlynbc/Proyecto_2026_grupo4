import '../../../core/network/api_exception.dart';
import '../../agenda/models/appointment.dart';
import '../models/arrival.dart';

/// Registro del aviso de llegada de un socio en ventanilla (RF-16).
abstract class ArrivalRepository {
  /// Consultas agendadas de hoy del socio con esa cédula.
  Future<List<Appointment>> listTodayAppointments(String ci);

  /// Registra la llegada del socio. Si ya estaba registrada, devuelve el aviso
  /// original con [ArrivalResult.created] en `false`.
  Future<ArrivalResult> registerArrival(String ci);
}

/// La cédula queda solo con dígitos: "9.000.004-6" pasa a "90000046".
String normalizeCi(String ci) => ci.replaceAll(RegExp(r'\D'), '');

/// La cédula no es válida (`VALIDACION`, 400).
class ArrivalValidationException extends ApiException {
  const ArrivalValidationException(super.message);
}

/// No hay un socio activo con esa cédula (`NO_ENCONTRADO`, 404).
class MemberNotFoundException extends ApiException {
  const MemberNotFoundException([
    super.message =
        'No encontramos un socio activo con esa cédula. Revisá el número '
        'y probá de nuevo.',
  ]);
}

/// El funcionario intenta registrar su propia llegada (`CONFLICTO_INTERES` en
/// el código, `CONFLICTO_DE_INTERES` en el contrato; 403).
class ConflictOfInterestException extends ApiException {
  const ConflictOfInterestException([
    super.message =
        'No podés registrar tu propia llegada. Pedile a otro funcionario '
        'que la registre.',
  ]);
}

/// El socio no tiene consultas agendadas hoy (`SIN_CONSULTAS_AGENDADAS` en el
/// código, `SIN_CONSULTAS_HOY` en el contrato; 409).
class NoAppointmentsTodayException extends ApiException {
  const NoAppointmentsTodayException([
    super.message =
        'El socio no tiene consultas agendadas para hoy, así que no se '
        'puede registrar su llegada.',
  ]);
}
