import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/agenda_time.dart';
import '../../agenda/models/appointment.dart' show kAppointmentStatuses;
import '../../agenda/models/available_number.dart' show DoctorRef;
import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';

/// Un instante con zona: termina en `Z` o en un desplazamiento `+hh:mm`. Sin
/// zona, `DateTime.parse` lo tomaría como hora del dispositivo y correría la
/// hora en silencio.
final RegExp _zonePattern = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

DateTime _parseInstant(String value) {
  if (!_zonePattern.hasMatch(value)) {
    throw FormatException('Instante sin zona horaria', value);
  }
  return DateTime.parse(value);
}

String _statusFromApi(String value) {
  if (!kAppointmentStatuses.contains(value)) {
    throw FormatException('Estado de consulta desconocido', value);
  }
  return value;
}

/// El socio de una consulta de la agenda (`socio`, contrato #28). Solo lo que
/// hace falta para identificarlo.
class ScheduleMember {
  const ScheduleMember({
    required this.ci,
    required this.firstName,
    required this.lastName,
  });

  factory ScheduleMember.fromJson(Map<String, dynamic> json) => ScheduleMember(
    ci: json['ci'] as String,
    firstName: json['nombre'] as String,
    lastName: json['apellido'] as String,
  );

  final String ci;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName';
}

/// Una consulta de la agenda operativa (`AgendaOperativaDTO`, contrato #28):
/// sin datos clínicos. `fecha` y las horas son locales de Uruguay; `llegadaEn`
/// es un instante y se muestra pasado a hora de Uruguay.
class ScheduleEntry {
  const ScheduleEntry({
    required this.appointmentId,
    required this.member,
    required this.doctor,
    required this.specialty,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.clinic,
    required this.status,
    required this.arrivedAt,
  });

  /// Un estado desconocido, una hora o un instante mal formados tiran
  /// `FormatException`; un campo faltante, `TypeError`. El repository traduce
  /// las dos al error genérico.
  factory ScheduleEntry.fromJson(Map<String, dynamic> json) => ScheduleEntry(
    appointmentId: json['consultaId'] as int,
    member: ScheduleMember.fromJson(json['socio'] as Map<String, dynamic>),
    doctor: DoctorRef.fromJson(json['medico'] as Map<String, dynamic>),
    specialty: Specialty.fromJson(json['especialidad'] as Map<String, dynamic>),
    date: parseApiDate(json['fecha'] as String),
    startMinutes: parseApiTime(json['horaInicio'] as String),
    endMinutes: parseApiTime(json['horaFin'] as String),
    clinic: Clinic.fromJson(json['consultorio'] as Map<String, dynamic>),
    status: _statusFromApi(json['estado'] as String),
    arrivedAt: json['llegadaEn'] == null
        ? null
        : _parseInstant(json['llegadaEn'] as String),
  );

  final int appointmentId;
  final ScheduleMember member;
  final DoctorRef doctor;
  final Specialty specialty;

  /// Clave de día en UTC, como la de `Appointment`.
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final Clinic clinic;

  /// Uno de `kAppointmentStatuses`.
  final String status;

  /// Cuándo avisó su llegada, o `null` si no la registró ese día.
  final DateTime? arrivedAt;

  String get startTime => formatMinutes(startMinutes);

  String get endTime => formatMinutes(endMinutes);

  /// La hora de llegada como `HH:mm` de Uruguay, o `null` sin aviso.
  String? get arrivalTime {
    final instant = arrivedAt;
    if (instant == null) return null;
    final local = UruguayTime.toUruguay(instant);
    return formatMinutes(local.hour * 60 + local.minute);
  }
}
