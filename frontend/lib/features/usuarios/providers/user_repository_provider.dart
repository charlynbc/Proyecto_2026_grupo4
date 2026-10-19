import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_user_repository.dart';
import '../repositories/fake_user_repository.dart';
import '../repositories/user_repository.dart';

/// Punto único de inyección del repositorio de usuarios. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final userRepositoryProvider = FutureProvider<UserRepository>((ref) async {
  if (ref.watch(useFakesProvider)) {
    return FakeUserRepository(ref.watch(fakeAdminDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiUserRepository(dio);
});
