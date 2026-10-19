import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/clinic.dart';
import 'clinic_repository_provider.dart';

/// El catálogo de consultorios; el alta de uno lo invalida.
final clinicsProvider = FutureProvider<List<Clinic>>((ref) async {
  final repository = await ref.watch(clinicRepositoryProvider.future);
  return repository.list();
});
