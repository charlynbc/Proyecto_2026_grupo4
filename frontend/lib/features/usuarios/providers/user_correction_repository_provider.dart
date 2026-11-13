import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_user_correction_repository.dart';
import '../repositories/fake_user_correction_repository.dart';
import '../repositories/user_correction_repository.dart';

/// Punto único de inyección del repositorio que lee y corrige cuentas. Con
/// `USE_FAKES=true` devuelve la implementación en memoria, sobre la misma base
/// falsa que el padrón.
final userCorrectionRepositoryProvider =
    FutureProvider<UserCorrectionRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeUserCorrectionRepository(
          ref.watch(fakeAdminDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiUserCorrectionRepository(dio);
    });
