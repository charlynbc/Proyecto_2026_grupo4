import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_user_import_repository.dart';
import '../repositories/fake_user_import_repository.dart';
import '../repositories/user_import_repository.dart';

/// Punto único de inyección del repositorio de la carga masiva de usuarios.
/// Con `USE_FAKES=true` devuelve la implementación en memoria, que comparte
/// el padrón con el resto de los repositories falsos del administrador.
final userImportRepositoryProvider = FutureProvider<UserImportRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return FakeUserImportRepository(ref.watch(fakeAdminDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiUserImportRepository(dio);
});
