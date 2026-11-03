/// Órdenes ascendentes disponibles para consultar especialidades.
enum SpecialtyOrder { name, createdAt }

/// Filtros combinables de RF-36, sin sentido ni paginación.
class SpecialtyFilters {
  const SpecialtyFilters({
    this.name,
    this.requiresReferral,
    this.order = SpecialtyOrder.name,
  });

  final String? name;

  /// null representa Todas; true, Sí; false, No.
  final bool? requiresReferral;
  final SpecialtyOrder order;

  /// Envía únicamente los filtros utilizados, con el nombre recortado.
  Map<String, dynamic> toQueryParameters() {
    final search = name?.trim();
    if (search != null && search.length > 120) {
      throw ArgumentError.value(
        search,
        'name',
        'El nombre no puede superar los 120 caracteres.',
      );
    }

    return {
      if (search != null && search.isNotEmpty) 'nombre': search,
      if (requiresReferral != null) 'requierePase': requiresReferral,
      if (order == SpecialtyOrder.createdAt) 'orden': 'fechaAlta',
    };
  }
}
