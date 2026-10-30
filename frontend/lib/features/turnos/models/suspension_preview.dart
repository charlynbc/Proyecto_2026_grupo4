import 'shift_date_format.dart';
import 'shift_number.dart';

/// Una fecha que la suspensión afecta, con las consultas que se cancelarían
/// (`fechasAfectadas`, contrato #23).
class AffectedShiftDate {
  const AffectedShiftDate({
    required this.shiftId,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.appointmentsToCancel,
  });

  factory AffectedShiftDate.fromJson(Map<String, dynamic> json) =>
      AffectedShiftDate(
        shiftId: json['turnoId'] as int,
        date: parseDateKey(json['fecha'] as String),
        startMinutes: ShiftNumber.parseTime(json['horaInicio'] as String),
        endMinutes: ShiftNumber.parseTime(json['horaFin'] as String),
        appointmentsToCancel: json['consultasACancelar'] as int,
      );

  final int shiftId;

  /// Clave de día en UTC.
  final DateTime date;

  /// Minutos desde las 00:00.
  final int startMinutes;
  final int endMinutes;
  final int appointmentsToCancel;
}

/// Lo que pasaría al suspender los turnos elegidos (`VistaPreviaSuspensionDTO`,
/// contrato #23). [totalAppointments] es la cantidad que el servidor pide
/// confirmar al suspender.
class SuspensionPreview {
  const SuspensionPreview({
    required this.affectedDates,
    required this.totalAppointments,
  });

  factory SuspensionPreview.fromJson(Map<String, dynamic> json) =>
      SuspensionPreview(
        affectedDates: [
          for (final item in json['fechasAfectadas'] as List<dynamic>)
            AffectedShiftDate.fromJson(item as Map<String, dynamic>),
        ],
        totalAppointments: json['cantidadConsultasACancelar'] as int,
      );

  final List<AffectedShiftDate> affectedDates;
  final int totalAppointments;
}
