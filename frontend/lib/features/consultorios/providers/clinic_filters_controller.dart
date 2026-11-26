import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic_filters.dart';

/// Conserva solo los filtros aplicados; la edición pertenece a la barra.
class ClinicFiltersController extends Notifier<ClinicFilters> {
  int _searchRevision = 0;

  /// Buscar y Limpiar recargan aunque los parámetros sean los mismos.
  /// Se incrementa antes de publicar el estado; no es un parámetro de la API.
  int get searchRevision => _searchRevision;

  @override
  ClinicFilters build() => const ClinicFilters();

  /// Buscar aplica el texto junto con el orden ya elegido.
  /// El sentido queda como estaba.
  void apply({
    String? name,
    String? location,
    ClinicOrder order = ClinicOrder.name,
  }) {
    _searchRevision++;
    state = ClinicFilters(
      name: name,
      location: location,
      order: order,
      ascending: state.ascending,
    );
  }

  /// El orden nuevo usa los filtros del último Buscar, no lo escrito sin buscar.
  void sortBy(ClinicOrder order) {
    state = ClinicFilters(
      name: state.name,
      location: state.location,
      order: order,
      ascending: state.ascending,
    );
  }

  /// Invierte la lista que ya está cargada, sin otra consulta.
  void toggleDirection() {
    state = ClinicFilters(
      name: state.name,
      location: state.location,
      order: state.order,
      ascending: !state.ascending,
    );
  }

  /// Una consulta nueva, con los valores por defecto, permite recargar.
  void clear() {
    _searchRevision++;
    state = ClinicFilters();
  }
}

final clinicFiltersControllerProvider =
    NotifierProvider.autoDispose<ClinicFiltersController, ClinicFilters>(
      ClinicFiltersController.new,
    );
