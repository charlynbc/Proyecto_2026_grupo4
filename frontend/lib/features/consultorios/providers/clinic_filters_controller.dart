import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic_filters.dart';

/// Conserva solo los filtros aplicados; la edición pertenece a la barra.
class ClinicFiltersController extends Notifier<ClinicFilters> {
  @override
  ClinicFilters build() => const ClinicFilters();

  /// Buscar aplica todos los valores juntos, incluidos los filtros vacíos.
  void apply({
    String? name,
    String? location,
    ClinicOrder order = ClinicOrder.name,
  }) {
    state = ClinicFilters(name: name, location: location, order: order);
  }

  /// Una consulta nueva, con los valores por defecto, permite recargar.
  void clear() {
    state = ClinicFilters();
  }
}

final clinicFiltersControllerProvider =
    NotifierProvider.autoDispose<ClinicFiltersController, ClinicFilters>(
      ClinicFiltersController.new,
    );
