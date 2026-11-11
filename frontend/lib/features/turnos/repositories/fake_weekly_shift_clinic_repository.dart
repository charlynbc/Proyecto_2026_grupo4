import '../../../core/fakes/fake_shift_database.dart';
import '../models/weekly_shift.dart';
import '../models/clinic_change_preview.dart';
import 'weekly_shift_clinic_repository.dart';

/// Implementación en memoria de [WeeklyShiftClinicRepository]. Las reglas
/// viven en [FakeShiftDatabase].
class FakeWeeklyShiftClinicRepository implements WeeklyShiftClinicRepository {
  FakeWeeklyShiftClinicRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeShiftDatabase _db;
  final Duration latency;

  @override
  Future<ClinicChangePreview> previewClinicChange(
    int weeklyShiftId,
    int clinicId,
  ) async {
    await Future<void>.delayed(latency);
    return _db.previewClinicChange(weeklyShiftId, clinicId);
  }

  @override
  Future<WeeklyShift> changeClinic(int weeklyShiftId, int clinicId) async {
    await Future<void>.delayed(latency);
    return _db.changeClinic(weeklyShiftId, clinicId);
  }
}
