import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import 'agenda_time.dart';

/// El médico de un número (`medico` de `GET /api/disponibilidad` y de la
/// consulta creada). Es lo único que se sabe de él: no hay catálogo de médicos.
class DoctorRef {
  const DoctorRef({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  factory DoctorRef.fromJson(Map<String, dynamic> json) => DoctorRef(
    id: json['id'] as int,
    firstName: json['nombre'] as String,
    lastName: json['apellido'] as String,
  );

  final int id;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName';
}

/// Un número libre de un turno (`NumeroDisponible`, contrato #16). La fecha y
/// las horas son locales de Uruguay, tal como las manda el servidor.
class AvailableNumber {
  const AvailableNumber({
    required this.numberId,
    required this.shiftId,
    required this.number,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.doctor,
    required this.specialty,
    required this.clinic,
  });

  factory AvailableNumber.fromJson(Map<String, dynamic> json) =>
      AvailableNumber(
        numberId: json['numeroId'] as int,
        shiftId: json['turnoId'] as int,
        number: json['numero'] as int,
        date: parseApiDate(json['fecha'] as String),
        startMinutes: parseApiTime(json['horaInicio'] as String),
        endMinutes: parseApiTime(json['horaFin'] as String),
        doctor: DoctorRef.fromJson(json['medico'] as Map<String, dynamic>),
        specialty: Specialty.fromJson(
          json['especialidad'] as Map<String, dynamic>,
        ),
        clinic: Clinic.fromJson(json['consultorio'] as Map<String, dynamic>),
      );

  final int numberId;
  final int shiftId;

  /// Posición del número dentro del turno.
  final int number;

  /// Clave de día (UTC sin hora): se muestra con `formatUiDate`.
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final DoctorRef doctor;
  final Specialty specialty;
  final Clinic clinic;

  String get timeRange =>
      '${formatMinutes(startMinutes)} - ${formatMinutes(endMinutes)}';
}

/// Lo que devuelve `GET /api/disponibilidad`: `{ "items": [...] }`.
List<AvailableNumber> availableNumbersFromJson(Map<String, dynamic> json) => [
  for (final item in json['items'] as List<dynamic>)
    AvailableNumber.fromJson(item as Map<String, dynamic>),
];
