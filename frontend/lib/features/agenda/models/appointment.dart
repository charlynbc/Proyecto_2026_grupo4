import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import 'agenda_time.dart';
import 'available_number.dart';

/// La consulta que devuelve `POST /api/consultas` (`Consulta`, contrato #17).
/// `fecha` y las horas son locales de Uruguay; `agendadaEn` y `canceladaEn`
/// son instantes y se muestran pasados a hora de Uruguay.
class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.date,
    required this.number,
    required this.startMinutes,
    required this.endMinutes,
    required this.doctor,
    required this.specialty,
    required this.clinic,
    required this.referralId,
    required this.bookedAt,
    required this.cancelledAt,
    required this.cancellationReason,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as int,
    status: json['estado'] as String,
    date: parseApiDate(json['fecha'] as String),
    number: json['numero'] as int,
    startMinutes: parseApiTime(json['horaInicio'] as String),
    endMinutes: parseApiTime(json['horaFin'] as String),
    doctor: DoctorRef.fromJson(json['medico'] as Map<String, dynamic>),
    specialty: Specialty.fromJson(json['especialidad'] as Map<String, dynamic>),
    clinic: Clinic.fromJson(json['consultorio'] as Map<String, dynamic>),
    referralId: json['paseId'] as int?,
    bookedAt: DateTime.parse(json['agendadaEn'] as String),
    cancelledAt: json['canceladaEn'] == null
        ? null
        : DateTime.parse(json['canceladaEn'] as String),
    cancellationReason: json['motivoCancelacion'] as String?,
  );

  final int id;

  /// Los estados calculados de RF-11 no se persisten en PostgreSQL.
  final String status;
  final DateTime date;
  final int number;
  final int startMinutes;
  final int endMinutes;
  final DoctorRef doctor;
  final Specialty specialty;
  final Clinic clinic;
  final int? referralId;
  final DateTime bookedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  String get timeRange =>
      '${formatMinutes(startMinutes)} - ${formatMinutes(endMinutes)}';

  String get statusLabel => switch (status) {
    'AGENDADA' => 'Agendada',
    'ATENDIDA' => 'Atendida',
    'CANCELADA_SOCIO' => 'Cancelada por el socio',
    'CANCELADA_INSTITUCION' => 'Cancelada por la institución',
    'NO_SE_PRESENTO' => 'No se presentó',
    'NO_ASISTIO' => 'No asistió',
    'NO_ATENDIDA' => 'No atendida',
    _ => status,
  };
}
