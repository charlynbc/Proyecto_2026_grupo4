import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic.dart';
import '../models/clinic_filters.dart';
import '../natural_order.dart';
import 'clinic_filters_controller.dart';
import 'clinic_search_repository_provider.dart';

/// Busca con nombre, ubicación y orden.
///
/// No observa el sentido: alternarlo no repite la consulta. Buscar, cambiar
/// el orden y Limpiar invalidan este provider a propósito.
final clinicSearchProvider = FutureProvider.autoDispose<List<Clinic>>((
  ref,
) async {
  final filters = ref.read(clinicFiltersControllerProvider);
  final repository = await ref.watch(clinicSearchRepositoryProvider.future);
  return repository.search(
    ClinicFilters(
      name: filters.name,
      location: filters.location,
      order: filters.order,
    ),
  );
}, retry: (_, _) => null);

/// La lista que ve la pantalla.
///
/// Ordena acá, con números como cantidad, y Descendente invierte esa copia.
/// No repite la consulta ni manda el sentido.
final clinicListProvider = Provider<AsyncValue<List<Clinic>>>((ref) {
  final ascending = ref.watch(
    clinicFiltersControllerProvider.select((filters) => filters.ascending),
  );
  final order = ref.watch(
    clinicFiltersControllerProvider.select((filters) => filters.order),
  );
  return ref.watch(clinicSearchProvider).whenData((items) {
    final sorted = sortedNaturally(items, (clinic) {
      return order == ClinicOrder.location ? clinic.location : clinic.name;
    });
    return ascending ? sorted : sorted.reversed.toList();
  });
});
