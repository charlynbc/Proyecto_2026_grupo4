import '../../../core/fakes/fake_shift_database.dart';
import 'shift_reinstatement_repository.dart';

/// Implementación en memoria de [ShiftReinstatementRepository]. Las reglas
/// viven en [FakeShiftDatabase.reinstateShift].
class FakeShiftReinstatementRepository implements ShiftReinstatementRepository {
  FakeShiftReinstatementRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeShiftDatabase _db;
  final Duration latency;

  @override
  Future<ShiftReinstatementResult> reinstate(
    ShiftReinstatement request,
  ) async {
    await Future<void>.delayed(latency);
    final shifts = <ReinstatedShift>[];
    for (final id in request.shiftIds) {
      final date = _db.shifts.firstWhere((shift) => shift.id == id).date;
      _db.reinstateShift(id);
      shifts.add(ReinstatedShift(id: id, date: date));
    }
    return ShiftReinstatementResult(
      shifts: shifts,
      cancelledAppointments: 0,
    );
  }
}
