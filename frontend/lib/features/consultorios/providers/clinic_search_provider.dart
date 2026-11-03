import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic.dart';
import 'clinic_filters_controller.dart';
import 'clinic_search_repository_provider.dart';

/// Busca con los filtros aplicados; invalidar repite la misma búsqueda.
final clinicSearchProvider = FutureProvider.autoDispose<List<Clinic>>((
  ref,
) async {
  final filters = ref.watch(clinicFiltersControllerProvider);
  final repository = await ref.watch(clinicSearchRepositoryProvider.future);
  return repository.search(filters);
}, retry: (_, _) => null);
