import '../../../core/fakes/fake_admin_database.dart';
import '../models/specialty.dart';
import 'specialty_correction_repository.dart';

/// Implementación en memoria de [SpecialtyCorrectionRepository] para
/// `USE_FAKES=true`. Reemplaza la especialidad dentro de `db.specialties` y
/// aplica las reglas del servidor, en este orden: que exista, el largo del
/// nombre y que no repita otra (sin distinguir mayúsculas).
class FakeSpecialtyCorrectionRepository
    implements SpecialtyCorrectionRepository {
  FakeSpecialtyCorrectionRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;

  @override
  Future<Specialty> correct(
    int id, {
    String? name,
    bool? requiresReferral,
  }) async {
    await Future<void>.delayed(latency);
    final index = _db.specialties.indexWhere((s) => s.id == id);
    if (index == -1) {
      throw const SpecialtyCorrectionException(
        SpecialtyCorrectionFailure.notFound,
        'No se encontró la especialidad.',
      );
    }
    final trimmed = name?.trim();
    if (trimmed != null) {
      if (trimmed.isEmpty) {
        throw const SpecialtyCorrectionException(
          SpecialtyCorrectionFailure.validation,
          'El nombre es obligatorio',
        );
      }
      if (trimmed.length > 120) {
        throw const SpecialtyCorrectionException(
          SpecialtyCorrectionFailure.validation,
          'El nombre supera 120 caracteres',
        );
      }
      final key = FakeAdminDatabase.normalize(trimmed);
      if (_db.specialties.any(
        (s) => s.id != id && FakeAdminDatabase.normalize(s.name) == key,
      )) {
        throw const SpecialtyCorrectionException(
          SpecialtyCorrectionFailure.duplicate,
          'Ya existe una especialidad registrada con ese nombre.',
        );
      }
    }
    final current = _db.specialties[index];
    final updated = Specialty(
      id: current.id,
      name: trimmed ?? current.name,
      requiresReferral: requiresReferral ?? current.requiresReferral,
    );
    _db.specialties[index] = updated;
    return updated;
  }
}
