import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_password_recovery_link_repository.dart';
import '../repositories/fake_password_recovery_link_repository.dart';
import '../repositories/password_recovery_link_repository.dart';

/// Punto único de inyección del validador del enlace de recuperación. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final passwordRecoveryLinkRepositoryProvider =
    FutureProvider<PasswordRecoveryLinkRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakePasswordRecoveryLinkRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiPasswordRecoveryLinkRepository(dio);
    });
