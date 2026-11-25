import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/refetch_when_visible_again.dart';
import '../models/clinic.dart';
import '../models/clinic_filters.dart';
import 'clinic_filters_controller.dart';
import 'clinic_search_repository_provider.dart';

/// Busca con nombre, ubicación y orden.
///
/// Observa esos tres y el contador de búsqueda: un cambio de filtro o de
/// orden, Buscar y Limpiar vuelven a pedir como una recarga nueva. El sentido
/// no se observa: alternarlo no repite la consulta. Al volver a verse la
/// pantalla (otra sección o el segundo plano) se pide de nuevo con los mismos
/// filtros. La pantalla tiene que observar este provider directamente: a
/// través de otro provider, `refetchWhenVisibleAgain` entra en un bucle.
final clinicSearchProvider = FutureProvider.autoDispose<List<Clinic>>((
  ref,
) async {
  refetchWhenVisibleAgain(ref, ref.invalidateSelf);
  final controller = ref.watch(clinicFiltersControllerProvider.notifier);
  final query = ref.watch(
    clinicFiltersControllerProvider.select(
      (filters) => (
        name: filters.name,
        location: filters.location,
        order: filters.order,
        revision: controller.searchRevision,
      ),
    ),
  );
  final repository = await ref.watch(clinicSearchRepositoryProvider.future);
  return repository.search(
    ClinicFilters(
      name: query.name,
      location: query.location,
      order: query.order,
    ),
  );
}, retry: (_, _) => null);
