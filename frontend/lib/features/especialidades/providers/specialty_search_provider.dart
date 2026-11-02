import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/specialty.dart';
import 'specialty_filters_controller.dart';
import 'specialty_search_repository_provider.dart';

/// Busca con los filtros aplicados; invalidar repite la misma búsqueda.
final specialtySearchProvider = FutureProvider.autoDispose<List<Specialty>>((
  ref,
) async {
  final filters = ref.watch(specialtyFiltersControllerProvider);
  final repository = await ref.watch(specialtySearchRepositoryProvider.future);
  return repository.search(filters);
}, retry: (_, _) => null);
