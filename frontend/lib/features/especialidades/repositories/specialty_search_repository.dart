import '../../../core/network/api_exception.dart';
import '../models/specialty.dart';
import '../models/specialty_filters.dart';

/// Búsqueda de especialidades de RF-36, independiente del catálogo compartido.
abstract class SpecialtySearchRepository {
  Future<List<Specialty>> search(SpecialtyFilters filters);
}

enum SpecialtySearchFailure { validation, unauthenticated, forbidden, other }

/// Error de búsqueda compatible con los mensajes compartidos de la API.
class SpecialtySearchException extends ApiException {
  const SpecialtySearchException(this.failure, [super.message]);

  final SpecialtySearchFailure failure;
}
