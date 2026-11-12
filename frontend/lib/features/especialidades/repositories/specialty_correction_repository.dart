import '../../../core/network/api_exception.dart';
import '../models/specialty.dart';

/// Corrección de una especialidad (contrato, fila 59, RF-38). Es un
/// repositorio aparte para no tocar [SpecialtyRepository] ni sus dobles.
abstract class SpecialtyCorrectionRepository {
  /// Corrige el nombre y/o la exigencia de pase de la especialidad [id].
  /// Solo se manda lo que se recibe; lo que queda en `null` no se toca.
  Future<Specialty> correct(int id, {String? name, bool? requiresReferral});
}

/// Por qué no se pudo corregir.
enum SpecialtyCorrectionFailure { notFound, duplicate, validation, other }

/// Una corrección rechazada. El [message] es el del servidor.
class SpecialtyCorrectionException extends ApiException {
  const SpecialtyCorrectionException(this.failure, [super.message]);

  final SpecialtyCorrectionFailure failure;
}
