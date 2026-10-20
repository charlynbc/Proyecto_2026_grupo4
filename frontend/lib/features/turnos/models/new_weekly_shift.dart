import 'shift_date_format.dart';
import 'shift_number.dart';

/// Los datos para dar de alta un turno semanal (`AltaTurnoDTO`).
///
/// [weekday] va de 1 (lunes) a 7 (domingo), como en el contrato. Las fechas
/// son claves de día en UTC, como las de `UruguayTime`.
class NewWeeklyShift {
  const NewWeeklyShift({
    required this.doctorId,
    required this.specialtyId,
    required this.clinicId,
    required this.weekday,
    required this.startDate,
    required this.endDate,
    required this.numbers,
  });

  final int doctorId;
  final int specialtyId;
  final int clinicId;
  final int weekday;
  final DateTime startDate;
  final DateTime endDate;
  final List<ShiftNumber> numbers;

  /// El cuerpo de `POST /api/turnos-semanales` (#13): `diaSemana` de 1 a 7,
  /// fechas `yyyy-MM-dd` y horas `HH:mm`.
  Map<String, dynamic> toJson() => {
    'medicoId': doctorId,
    'especialidadId': specialtyId,
    'consultorioId': clinicId,
    'diaSemana': weekday,
    'fechaInicio': formatDateKey(startDate),
    'fechaFin': formatDateKey(endDate),
    'numeros': [for (final number in numbers) number.toJson()],
  };
}
