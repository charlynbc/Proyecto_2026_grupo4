import '../../../core/fakes/fake_admin_database.dart';
import '../models/clinic.dart';
import 'clinic_repository.dart';

/// Implementación en memoria de [ClinicRepository] para `USE_FAKES=true`.
/// Aplica la regla del servidor: el nombre o número es único una vez
/// normalizado (`CONSULTORIO_DUPLICADO`).
class FakeClinicRepository implements ClinicRepository {
  FakeClinicRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  @override
  Future<List<Clinic>> list() async {
    await Future<void>.delayed(latency);
    final sorted = [..._db.clinics];
    sorted.sort(
      (a, b) =>
          FakeAdminDatabase.normalize(a.name)
              .compareTo(FakeAdminDatabase.normalize(b.name)),
    );
    return sorted;
  }

  @override
  Future<Clinic> create({
    required String name,
    required String location,
  }) async {
    await Future<void>.delayed(latency);
    final key = FakeAdminDatabase.normalize(name);
    if (_db.clinics.any((c) => FakeAdminDatabase.normalize(c.name) == key)) {
      throw const DuplicateClinicException();
    }
    final clinic = Clinic(
      id: _db.newClinicId(),
      name: name.trim(),
      location: location.trim(),
    );
    _db.clinics.add(clinic);
    return clinic;
  }
}
