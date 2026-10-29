import 'shift_date_format.dart';

/// El filtro que armó la lista de turnos a suspender (`FiltroFechasDTO`,
/// contrato #24). Los cuatro campos son obligatorios.
///
/// Las fechas son claves de día en UTC, ambas inclusive.
class SuspensionFilter {
  const SuspensionFilter({
    required this.doctorId,
    required this.specialtyId,
    required this.fromDate,
    required this.toDate,
  });

  final int doctorId;
  final int specialtyId;
  final DateTime fromDate;
  final DateTime toDate;

  Map<String, Object> toJson() => {
    'medicoId': doctorId,
    'especialidadId': specialtyId,
    'fechaDesde': formatDateKey(fromDate),
    'fechaHasta': formatDateKey(toDate),
  };
}
