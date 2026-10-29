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

  /// El mismo filtro con [fromDate] ajustado a [today] si era anterior: solo
  /// se suspenden fechas actuales o futuras. Este es el filtro que arma la
  /// lista y el que se envía al suspender.
  SuspensionFilter fromTodayOn(DateTime today) => fromDate.isBefore(today)
      ? SuspensionFilter(
          doctorId: doctorId,
          specialtyId: specialtyId,
          fromDate: today,
          toDate: toDate,
        )
      : this;

  @override
  bool operator ==(Object other) =>
      other is SuspensionFilter &&
      other.doctorId == doctorId &&
      other.specialtyId == specialtyId &&
      other.fromDate == fromDate &&
      other.toDate == toDate;

  @override
  int get hashCode => Object.hash(doctorId, specialtyId, fromDate, toDate);

  Map<String, Object> toJson() => {
    'medicoId': doctorId,
    'especialidadId': specialtyId,
    'fechaDesde': formatDateKey(fromDate),
    'fechaHasta': formatDateKey(toDate),
  };
}
