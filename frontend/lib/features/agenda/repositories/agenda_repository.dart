import '../../../core/network/api_exception.dart';
import '../models/appointment.dart';
import '../models/availability_query.dart';
import '../models/available_number.dart';
import '../models/referral.dart';

/// Disponibilidad (RF-08, contrato #16), alta de consultas (RF-09, contrato
/// #17) y los pases disponibles del socio
/// (`GET /api/socios/me/pases/disponibles`). Listar las consultas del socio
/// (RF-11) y cancelarlas no están en el backend todavía y por eso no figuran
/// acá.
abstract class AgendaRepository {
  /// Los números libres de la especialidad de [query], en el orden pedido.
  Future<List<AvailableNumber>> listAvailability(AvailabilityQuery query);

  /// Los pases del socio de la sesión que no están vencidos ni usados, en el
  /// orden del servidor (por vencimiento). No filtra por especialidad: eso es
  /// de quien lo pide.
  Future<List<Referral>> listReferrals();

  /// Agenda el número [numberId] para el socio de la sesión. [referralId] es
  /// el pase, que el servidor exige solo en las especialidades que lo piden.
  /// Los rechazos del negocio llegan como [BookingException].
  Future<Appointment> book({required int numberId, int? referralId});
}

/// Por qué el servidor rechazó agendar, según el `code` del error uniforme.
enum BookingFailure {
  /// `NUMERO_NO_DISPONIBLE`: otro socio lo tomó, o el turno ya no está activo.
  numberUnavailable,

  /// `ANTICIPACION_INVALIDA`: el número debe estar entre 2 horas y 30 días.
  outsideWindow,

  /// `LIMITE_TOTAL`: ya hay tres consultas agendadas.
  totalLimit,

  /// `LIMITE_ESPECIALIDAD`: ya hay una consulta agendada en la especialidad.
  specialtyLimit,

  /// `CONSULTA_SUPERPUESTA`: se superpone con otra del socio.
  overlap,

  /// `PASE_NO_VALIDO`: falta el pase o no es propio, vigente y sin usar.
  invalidReferral,

  /// `VALIDACION` (400): los datos enviados no son válidos.
  validation,

  /// `NO_ENCONTRADO` (404): el número o la cuenta del socio no existen.
  notFound,

  /// `NO_AUTENTICADO` (401): la sesión no es válida.
  unauthenticated,

  /// `ACCESO_DENEGADO` (403): el rol no puede agendar.
  forbidden,

  /// Sin respuesta del servidor o un `code` que no se conoce.
  other,
}

/// Un rechazo al agendar. El mensaje es el del servidor (seguro para mostrar)
/// y la pantalla decide qué hacer por [failure], nunca por el texto.
class BookingException extends ApiException {
  const BookingException(this.failure, [super.message]);

  final BookingFailure failure;

  /// La disponibilidad mostrada quedó vieja: conviene volver a pedirla.
  bool get availabilityIsStale =>
      failure == BookingFailure.numberUnavailable ||
      failure == BookingFailure.outsideWindow ||
      failure == BookingFailure.notFound;
}
