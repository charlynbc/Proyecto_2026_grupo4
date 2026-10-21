import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_auth_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/fake_auth_repository.dart';
import 'session_provider.dart';

/// Punto único de inyección del repositorio de auth. Con `USE_FAKES=true`
/// (ver [useFakesProvider]) devuelve la implementación en memoria; si no, la
/// de la API. Es async porque [dioProvider] lo es (tiene que esperar la
/// configuración de cookies según plataforma antes de devolver el `Dio`).
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final session = ref.read(sessionProvider.notifier);
  if (ref.watch(useFakesProvider)) return FakeAuthRepository(session);
  final dio = await ref.watch(dioProvider.future);
  return ApiAuthRepository(dio, session);
});
