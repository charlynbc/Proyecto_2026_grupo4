import '../models/doctor_shift.dart';

/// Turnos y pacientes del médico autenticado (RF-21).
abstract class DoctorShiftRepository {
  /// Los turnos propios de [date] (`yyyy-MM-dd`).
  Future<List<DoctorShift>> listShifts(String date);

  /// Todos los números del turno [shiftId]. [arrived] filtra por aviso de
  /// llegada (`null` = todos); [order] y [ascending] definen el orden.
  Future<DoctorShiftNumbers> listNumbers(
    int shiftId, {
    bool? arrived,
    DoctorNumbersOrder order = DoctorNumbersOrder.time,
    bool ascending = true,
  });
}
