import '../../../core/fakes/fake_shift_database.dart';
import '../../../core/utils/uruguay_time.dart';
import '../models/shift_state.dart';
import 'shift_reinstatement_repository.dart';
import 'shift_repository.dart';

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
    final now = UruguayTime.toUruguay(_db.admin.clock());
    final today = DateTime.utc(now.year, now.month, now.day);
    final chosen = <FakeShift>[];
    for (final id in request.shiftIds) {
      final matches = _db.shifts.where((shift) => shift.id == id);
      if (matches.isEmpty) throw const ShiftNotFoundException();
      final shift = matches.first;
      if (shift.state != ShiftState.suspended || shift.date.isBefore(today)) {
        throw const ShiftNotReinstatableException();
      }
      chosen.add(shift);
    }
    final shifts = <ReinstatedShift>[];
    for (final shift in chosen) {
      _db.reinstateShift(shift.id);
      shifts.add(ReinstatedShift(id: shift.id, date: shift.date));
    }
    return ShiftReinstatementResult(
      shifts: shifts,
      cancelledAppointments: 0,
    );
  }
}
