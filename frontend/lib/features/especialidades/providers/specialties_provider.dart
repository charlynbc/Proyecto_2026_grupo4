import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/specialty.dart';
import 'specialty_repository_provider.dart';

/// El catálogo de especialidades. Lo usan el listado y el formulario de alta
/// de usuarios; el alta de una especialidad lo invalida.
final specialtiesProvider = FutureProvider<List<Specialty>>((ref) async {
  final repository = await ref.watch(specialtyRepositoryProvider.future);
  return repository.list();
});
