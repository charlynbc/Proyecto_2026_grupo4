import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../repositories/api_auth_repository.dart';
import '../repositories/auth_repository.dart';
import 'session_provider.dart';

/// Punto único de inyección del repositorio de auth. Es async porque
/// [dioProvider] lo es (tiene que esperar la configuración de cookies según
/// plataforma antes de devolver el `Dio`).
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final dio = await ref.watch(dioProvider.future);
  final session = ref.read(sessionProvider.notifier);
  return ApiAuthRepository(dio, session);
});
