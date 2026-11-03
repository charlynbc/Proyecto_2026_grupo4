import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic.dart';
import '../models/clinic_filters.dart';
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

/// La lista que ve la pantalla. Descendente invierte lo ya cargado.
final clinicListProvider = Provider<AsyncValue<List<Clinic>>>((ref) {
  final ascending = ref.watch(
    clinicFiltersControllerProvider.select((filters) => filters.ascending),
  );
  return ref.watch(clinicSearchProvider).whenData((items) {
    return ascending ? items : items.reversed.toList();
  });
});
