import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/specialty_filters.dart';

/// Conserva solo los filtros aplicados; la edición pertenece a la barra.
class SpecialtyFiltersController extends Notifier<SpecialtyFilters> {
  int _searchRevision = 0;

  /// Buscar y Limpiar recargan aunque los parámetros sean los mismos.
  /// Se incrementa antes de publicar el estado; no es un parámetro de la API.
  int get searchRevision => _searchRevision;

  @override
  SpecialtyFilters build() => const SpecialtyFilters();

  /// Buscar aplica todos los valores juntos, incluidos los filtros vacíos.
  void apply({
    String? name,
    bool? requiresReferral,
    SpecialtyOrder order = SpecialtyOrder.name,
  }) {
    _searchRevision++;
    state = SpecialtyFilters(
      name: name,
      requiresReferral: requiresReferral,
      order: order,
      ascending: state.ascending,
    );
  }

  /// Cambia el orden aplicado sin incorporar la edición pendiente de la barra.
  void sortBy(SpecialtyOrder order, {required bool ascending}) {
    state = state.copyWith(order: order, ascending: ascending);
  }

  /// Una nueva consulta predeterminada permite recargar incluso estando limpio.
  void clear() {
    _searchRevision++;
    state = SpecialtyFilters();
  }
}

final specialtyFiltersControllerProvider =
    NotifierProvider.autoDispose<SpecialtyFiltersController, SpecialtyFilters>(
      SpecialtyFiltersController.new,
    );
