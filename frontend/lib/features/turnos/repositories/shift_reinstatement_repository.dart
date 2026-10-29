import '../../../core/network/api_exception.dart';

/// Pedido de rehabilitación (contrato #25): filtro de fechas e ids.
class ShiftReinstatement {
  const ShiftReinstatement({
    required this.doctorId,
    required this.specialtyId,
    required this.fromDate,
    required this.toDate,
    required this.shiftIds,
  });

  final int doctorId;
  final int specialtyId;

  /// Clave de día en UTC. Inclusive.
  final DateTime fromDate;

  /// Clave de día en UTC. Inclusive.
  final DateTime toDate;
  final List<int> shiftIds;
}

/// Un turno rehabilitado (`turnoId` y `fecha`).
class ReinstatedShift {
  const ReinstatedShift({required this.id, required this.date});

  final int id;

  /// Clave de día en UTC.
  final DateTime date;
}

/// Respuesta de #25. [cancelledAppointments] es `consultasCanceladas`.
class ShiftReinstatementResult {
  const ShiftReinstatementResult({
    required this.shifts,
    required this.cancelledAppointments,
  });

  final List<ReinstatedShift> shifts;
  final int cancelledAppointments;
}

abstract class ShiftReinstatementRepository {
  /// Vuelve a habilitar los turnos [request.shiftIds] del filtro.
  Future<ShiftReinstatementResult> reinstate(ShiftReinstatement request);
}

/// El turno no está suspendido o su fecha ya pasó (`TURNO_NO_REHABILITABLE`,
/// 409).
class ShiftNotReinstatableException extends ApiException {
  const ShiftNotReinstatableException([
    super.message =
        'Ese turno no se puede volver a habilitar: no está suspendido o la '
        'fecha ya pasó. Elegí otros turnos de la lista.',
  ]);

  String get code => 'TURNO_NO_REHABILITABLE';
}
