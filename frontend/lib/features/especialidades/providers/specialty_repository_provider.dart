import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_specialty_repository.dart';
import '../repositories/fake_specialty_repository.dart';
import '../repositories/specialty_repository.dart';

/// Punto único de inyección del repositorio de especialidades. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final specialtyRepositoryProvider = FutureProvider<SpecialtyRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return FakeSpecialtyRepository(ref.watch(fakeAdminDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiSpecialtyRepository(dio);
});
