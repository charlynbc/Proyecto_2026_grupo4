import '../../../core/network/api_exception.dart';
import '../models/clinic.dart';

/// Catálogo de consultorios (contrato #8 y #9, RF-33).
abstract class ClinicRepository {
  /// Todos los consultorios, ordenados por nombre.
  Future<List<Clinic>> list();

  /// Da de alta un consultorio. Lanza [DuplicateClinicException] si el
  /// nombre o número ya existe.
  Future<Clinic> create({required String name, required String location});
}

/// `CONSULTORIO_DUPLICADO`: el nombre o número ya existe (normalizado).
class DuplicateClinicException extends ApiException {
  const DuplicateClinicException([
    super.message = 'Ya existe un consultorio con ese nombre o número.',
  ]);
}
