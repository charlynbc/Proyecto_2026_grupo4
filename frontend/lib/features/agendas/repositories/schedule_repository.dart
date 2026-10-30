import '../../../core/network/api_exception.dart';
import '../models/schedule_filters.dart';
import '../models/schedule_page.dart';

abstract class ScheduleRepository {
  /// Una página de la agenda del día (RF-18), con los filtros, el orden y la
  /// paginación resueltos del lado del servidor.
  Future<SchedulePage> search(ScheduleFilters filters);
}

/// Un filtro que no cumple las reglas (`VALIDACION`, 400). El [message] es el
/// del servidor, por ejemplo "ci debe ser una cedula valida".
class ScheduleValidationException extends ApiException {
  const ScheduleValidationException(super.message);

  String get code => 'VALIDACION';
}
