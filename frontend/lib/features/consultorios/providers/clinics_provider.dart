import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic.dart';
import '../natural_order.dart';
import 'clinic_repository_provider.dart';

/// El catálogo de consultorios, ordenado por nombre como lo lee una persona.
/// El alta de uno lo invalida.
final clinicsProvider = FutureProvider<List<Clinic>>((ref) async {
  final repository = await ref.watch(clinicRepositoryProvider.future);
  final items = await repository.list();
  return sortedNaturally(items, (clinic) => clinic.name);
});
