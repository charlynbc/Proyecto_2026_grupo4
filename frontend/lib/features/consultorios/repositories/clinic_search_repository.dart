import '../../../core/network/api_exception.dart';
import '../models/clinic.dart';
import '../models/clinic_filters.dart';

/// Búsqueda de consultorios de RF-37, independiente del catálogo compartido.
abstract class ClinicSearchRepository {
  Future<List<Clinic>> search(ClinicFilters filters);
}

enum ClinicSearchFailure { validation, unauthenticated, forbidden, other }

/// Error de búsqueda compatible con los mensajes compartidos de la API.
class ClinicSearchException extends ApiException {
  const ClinicSearchException(this.failure, [super.message]);

  final ClinicSearchFailure failure;
}
