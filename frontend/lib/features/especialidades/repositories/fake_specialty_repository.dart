import '../../../core/fakes/fake_admin_database.dart';
import '../models/specialty.dart';
import 'specialty_repository.dart';

/// Implementación en memoria de [SpecialtyRepository] para `USE_FAKES=true`.
/// Aplica la regla del servidor: el nombre es único sin distinguir
/// mayúsculas (`ESPECIALIDAD_DUPLICADA`).
class FakeSpecialtyRepository implements SpecialtyRepository {
  FakeSpecialtyRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  @override
  Future<List<Specialty>> list() async {
    await Future<void>.delayed(latency);
    final sorted = [..._db.specialties];
    sorted.sort(
      (a, b) =>
          FakeAdminDatabase.normalize(a.name)
              .compareTo(FakeAdminDatabase.normalize(b.name)),
    );
    return sorted;
  }

  @override
  Future<Specialty> create({
    required String name,
    required bool requiresReferral,
  }) async {
    await Future<void>.delayed(latency);
    final key = FakeAdminDatabase.normalize(name);
    if (_db.specialties.any(
      (s) => FakeAdminDatabase.normalize(s.name) == key,
    )) {
      throw const DuplicateSpecialtyException();
    }
    final specialty = Specialty(
      id: _db.newSpecialtyId(),
      name: name.trim(),
      requiresReferral: requiresReferral,
    );
    _db.specialties.add(specialty);
    return specialty;
  }
}
