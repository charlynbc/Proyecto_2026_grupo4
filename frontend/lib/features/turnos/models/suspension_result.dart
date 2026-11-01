import 'shift_date_format.dart';

/// Un turno que quedó suspendido (`turnos`, contrato #24).
class SuspendedShift {
  const SuspendedShift({required this.shiftId, required this.date});

  factory SuspendedShift.fromJson(Map<String, dynamic> json) => SuspendedShift(
    shiftId: json['turnoId'] as int,
    date: parseDateKey(json['fecha'] as String),
  );

  final int shiftId;

  /// Clave de día en UTC.
  final DateTime date;
}

/// El resultado de suspender (`ResultadoFechasDTO`, contrato #24).
class SuspensionResult {
  const SuspensionResult({
    required this.shifts,
    required this.cancelledAppointments,
  });

  factory SuspensionResult.fromJson(Map<String, dynamic> json) =>
      SuspensionResult(
        shifts: [
          for (final item in json['turnos'] as List<dynamic>)
            SuspendedShift.fromJson(item as Map<String, dynamic>),
        ],
        cancelledAppointments: json['consultasCanceladas'] as int,
      );

  final List<SuspendedShift> shifts;
  final int cancelledAppointments;
}
