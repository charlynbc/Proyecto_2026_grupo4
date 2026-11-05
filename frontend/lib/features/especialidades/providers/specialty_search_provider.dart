import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/specialty.dart';
import '../models/specialty_filters.dart';
import 'specialty_filters_controller.dart';
import 'specialty_search_repository_provider.dart';

/// Consulta ascendente: nombre, pase, criterio y recargas explícitas.
/// El sentido no se observa ni se envía al repositorio.
final specialtySearchProvider = FutureProvider.autoDispose<List<Specialty>>((
  ref,
) async {
  final controller = ref.watch(specialtyFiltersControllerProvider.notifier);
  final query = ref.watch(
    specialtyFiltersControllerProvider.select(
      (filters) => (
        name: filters.name,
        requiresReferral: filters.requiresReferral,
        order: filters.order,
        revision: controller.searchRevision,
      ),
    ),
  );
  final repository = await ref.watch(specialtySearchRepositoryProvider.future);
  return repository.search(
    SpecialtyFilters(
      name: query.name,
      requiresReferral: query.requiresReferral,
      order: query.order,
    ),
  );
}, retry: (_, _) => null);

/// Aplica el sentido local sin consultar ni modificar la respuesta ascendente.
final specialtySearchResultsProvider =
    Provider.autoDispose<AsyncValue<List<Specialty>>>((ref) {
      final ascending = ref.watch(
        specialtyFiltersControllerProvider.select(
          (filters) => filters.ascending,
        ),
      );
      return ref
          .watch(specialtySearchProvider)
          .whenData((items) => ascending ? items : items.reversed.toList());
    });
