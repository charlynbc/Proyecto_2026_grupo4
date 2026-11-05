import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_password_recovery_repository.dart';
import '../repositories/fake_password_recovery_repository.dart';
import '../repositories/password_recovery_repository.dart';

/// Punto único de inyección del repositorio de recuperación de contraseña.
/// Con `USE_FAKES=true` devuelve la implementación en memoria.
final passwordRecoveryRepositoryProvider =
    FutureProvider<PasswordRecoveryRepository>((ref) async {
      if (ref.watch(useFakesProvider)) return FakePasswordRecoveryRepository();
      final dio = await ref.watch(dioProvider.future);
      return ApiPasswordRecoveryRepository(dio);
    });
