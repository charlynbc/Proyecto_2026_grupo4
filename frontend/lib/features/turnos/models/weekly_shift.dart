import '../../consultorios/models/clinic.dart';
import '../../especialidades/models/specialty.dart';
import 'doctor.dart';
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
