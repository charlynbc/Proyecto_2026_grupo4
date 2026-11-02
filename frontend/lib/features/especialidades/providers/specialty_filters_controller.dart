import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/specialty_filters.dart';

/// Conserva solo los filtros aplicados; la edición pertenece a la barra.
class SpecialtyFiltersController extends Notifier<SpecialtyFilters> {
  @override
  SpecialtyFilters build() => const SpecialtyFilters();

  /// Buscar aplica todos los valores juntos, incluidos los filtros vacíos.
  void apply({
    String? name,
    bool? requiresReferral,
    SpecialtyOrder order = SpecialtyOrder.name,
  }) {
    state = SpecialtyFilters(
      name: name,
      requiresReferral: requiresReferral,
      order: order,
    );
  }

  /// Una nueva consulta predeterminada permite recargar incluso estando limpio.
  void clear() {
    state = SpecialtyFilters();
  }
}

final specialtyFiltersControllerProvider =
    NotifierProvider.autoDispose<SpecialtyFiltersController, SpecialtyFilters>(
      SpecialtyFiltersController.new,
    );
