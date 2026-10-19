import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/fakes/fake_shift_database.dart';
import '../models/doctor.dart';
import '../models/new_weekly_shift.dart';
import '../models/weekly_shift.dart';
import 'shift_repository.dart';

/// Implementación en memoria de [ShiftRepository] para `USE_FAKES=true`. Las
/// reglas viven en [FakeShiftDatabase].
class FakeShiftRepository implements ShiftRepository {
  FakeShiftRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeShiftDatabase _db;
  final Duration latency;

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) async {
    await Future<void>.delayed(latency);
    final doctors = _db.activeDoctors().where(
      (d) =>
          specialtyId == null || d.specialties.any((s) => s.id == specialtyId),
    );
    return doctors.toList()..sort((a, b) {
      final byLastName = FakeAdminDatabase.normalize(a.lastName)
          .compareTo(FakeAdminDatabase.normalize(b.lastName));
      return byLastName != 0
          ? byLastName
          : FakeAdminDatabase.normalize(a.firstName)
                .compareTo(FakeAdminDatabase.normalize(b.firstName));
    });
  }

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) async {
    await Future<void>.delayed(latency);
    return _db.createWeeklyShift(data);
  }

  @override
  Future<WeeklyShift> getWeeklyShift(int id) async {
    await Future<void>.delayed(latency);
    final weeklyShift = _db.weeklyShiftById(id);
    if (weeklyShift == null) throw const ShiftNotFoundException();
    return weeklyShift;
  }
}
