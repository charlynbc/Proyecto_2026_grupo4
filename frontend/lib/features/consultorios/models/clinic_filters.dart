/// Órdenes ascendentes disponibles para consultar consultorios.
enum ClinicOrder { name, location }

/// Filtros combinables de RF-37, sin paginación.
///
/// [ascending] se resuelve en el cliente. La consulta no tiene sentido.
class ClinicFilters {
  const ClinicFilters({
    this.name,
    this.location,
    this.order = ClinicOrder.name,
    this.ascending = true,
  });

  final String? name;
  final String? location;
  final ClinicOrder order;

  /// false invierte la lista ya cargada. No se envía al servidor.
  final bool ascending;

  /// Envía solo los filtros usados. Los textos se recortan; el orden por
  /// nombre no se manda.
  Map<String, dynamic> toQueryParameters() {
    final search = name?.trim();
    final place = location?.trim();
    if (search != null && search.length > 120) {
      throw ArgumentError.value(
        search,
        'name',
        'El nombre no puede superar los 120 caracteres.',
      );
    }
    if (place != null && place.length > 200) {
      throw ArgumentError.value(
        place,
        'location',
        'La ubicación no puede superar los 200 caracteres.',
      );
    }

    return {
      if (search != null && search.isNotEmpty) 'nombre': search,
      if (place != null && place.isNotEmpty) 'ubicacion': place,
      if (order == ClinicOrder.location) 'orden': 'ubicacion',
    };
  }
}
