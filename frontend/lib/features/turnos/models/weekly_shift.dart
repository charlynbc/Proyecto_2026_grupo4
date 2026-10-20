import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import 'doctor.dart';
import 'shift_date_format.dart';
import 'shift_number.dart';

/// La configuración semanal de un turno (`TurnoSemanalDTO`): el patrón del que
/// salen las fechas concretas.
class WeeklyShift {
  const WeeklyShift({
    required this.id,
    required this.doctor,
    required this.specialty,
    required this.clinic,
    required this.weekday,
    required this.startDate,
    required this.endDate,
    required this.numbers,
    required this.shiftCount,
  });

  factory WeeklyShift.fromJson(Map<String, dynamic> json) => WeeklyShift(
    id: json['id'] as int,
    doctor: DoctorRef.fromJson(json['medico'] as Map<String, dynamic>),
    specialty: Specialty.fromJson(json['especialidad'] as Map<String, dynamic>),
    clinic: Clinic.fromJson(json['consultorio'] as Map<String, dynamic>),
    weekday: json['diaSemana'] as int,
    startDate: parseDateKey(json['fechaInicio'] as String),
    endDate: parseDateKey(json['fechaFin'] as String),
    numbers: [
      for (final number in json['numeros'] as List<dynamic>)
        ShiftNumber.fromJson(number as Map<String, dynamic>),
    ],
    shiftCount: json['cantidadTurnos'] as int,
  );

  final int id;
  final DoctorRef doctor;
  final Specialty specialty;
  final Clinic clinic;

  /// 1 es lunes y 7 es domingo.
  final int weekday;
  final DateTime startDate;
  final DateTime endDate;
  final List<ShiftNumber> numbers;

  /// Cuántas fechas concretas tiene (`cantidadTurnos`).
  final int shiftCount;
}
