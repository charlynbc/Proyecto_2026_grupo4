/// Órdenes ascendentes disponibles para consultar especialidades.
enum SpecialtyOrder { name, createdAt }

/// Filtros combinables de RF-36, con sentido local y sin paginación.
class SpecialtyFilters {
  static const _unchanged = Object();

  const SpecialtyFilters({
    this.name,
    this.requiresReferral,
    this.order = SpecialtyOrder.name,
    this.ascending = true,
  });

  final String? name;

  /// null representa Todas; true, Sí; false, No.
  final bool? requiresReferral;
  final SpecialtyOrder order;

  /// Solo afecta la presentación local; no se envía al servidor.
  final bool ascending;

  /// Omitir un campo lo conserva; null limpia nombre o requiere pase.
  SpecialtyFilters copyWith({
    Object? name = _unchanged,
    Object? requiresReferral = _unchanged,
    SpecialtyOrder? order,
    bool? ascending,
  }) {
    return SpecialtyFilters(
      name: identical(name, _unchanged) ? this.name : name as String?,
      requiresReferral: identical(requiresReferral, _unchanged)
          ? this.requiresReferral
          : requiresReferral as bool?,
      order: order ?? this.order,
      ascending: ascending ?? this.ascending,
    );
  }

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
