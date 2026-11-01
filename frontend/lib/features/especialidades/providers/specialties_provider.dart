import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/specialty.dart';
import 'specialty_repository_provider.dart';

/// El catálogo de especialidades. Lo usan el listado y el formulario de alta
/// de usuarios; el alta de una especialidad lo invalida.
///
/// Sin reintento automático (`retry` en `null`): las pantallas muestran el
/// aviso con "Reintentar" apenas falla, en vez de esperar los reintentos de
/// Riverpod.
final specialtiesProvider = FutureProvider<List<Specialty>>((ref) async {
  final repository = await ref.watch(specialtyRepositoryProvider.future);
  return repository.list();
}, retry: (_, _) => null);
