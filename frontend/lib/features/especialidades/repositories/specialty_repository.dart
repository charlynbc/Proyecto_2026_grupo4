import '../../../core/network/api_exception.dart';
import '../models/specialty.dart';

/// Catálogo de especialidades (contrato #6 y #7, RF-29).
abstract class SpecialtyRepository {
  /// Todas las especialidades, ordenadas por nombre.
  Future<List<Specialty>> list();

  /// Da de alta una especialidad. Lanza [DuplicateSpecialtyException] si ya
  /// hay una con ese nombre.
  Future<Specialty> create({
    required String name,
    required bool requiresReferral,
  });
}

/// `ESPECIALIDAD_DUPLICADA`: el nombre ya existe, sin distinguir mayúsculas.
class DuplicateSpecialtyException extends ApiException {
  const DuplicateSpecialtyException([
    super.message = 'Ya existe una especialidad registrada con ese nombre.',
  ]);
}
