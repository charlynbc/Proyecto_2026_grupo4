import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import 'doctor.dart';
import 'shift_date_format.dart';
import 'shift_number.dart';
import 'shift_state.dart';

/// Una fecha concreta de un turno semanal (`TurnoDTO`, contrato #15).
class Shift {
  const Shift({
    required this.id,
    required this.weeklyShiftId,
    required this.date,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    required this.doctor,
    required this.specialty,
    required this.clinic,
    required this.numberCount,
    required this.state,
  });

  factory Shift.fromJson(Map<String, dynamic> json) => Shift(
    id: json['id'] as int,
    weeklyShiftId: json['turnoSemanalId'] as int,
    date: parseDateKey(json['fecha'] as String),
    weekday: json['diaSemana'] as int,
    startMinutes: ShiftNumber.parseTime(json['horaInicio'] as String),
    endMinutes: ShiftNumber.parseTime(json['horaFin'] as String),
    doctor: DoctorRef.fromJson(json['medico'] as Map<String, dynamic>),
    specialty: Specialty.fromJson(json['especialidad'] as Map<String, dynamic>),
    clinic: Clinic.fromJson(json['consultorio'] as Map<String, dynamic>),
    numberCount: json['cantidadNumeros'] as int,
    state: ShiftState.fromApi(json['estado'] as String),
  );

  final int id;

  /// La configuración semanal de la que sale esta fecha (`turnoSemanalId`).
  final int weeklyShiftId;

  /// Clave de día en UTC.
  final DateTime date;

  /// 1 es lunes y 7 es domingo.
  final int weekday;

  /// Inicio del primer número y fin del último, en minutos desde las 00:00.
  final int startMinutes;
  final int endMinutes;

  final DoctorRef doctor;
  final Specialty specialty;
  final Clinic clinic;
  final int numberCount;
  final ShiftState state;
}
