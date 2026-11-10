import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_specialty_correction_repository.dart';
import '../repositories/fake_specialty_correction_repository.dart';
import '../repositories/specialty_correction_repository.dart';

/// Punto único de inyección del repositorio de corrección de especialidades.
/// Con `USE_FAKES=true` devuelve la implementación en memoria, sobre la misma
/// base falsa que el catálogo.
final specialtyCorrectionRepositoryProvider =
    FutureProvider<SpecialtyCorrectionRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeSpecialtyCorrectionRepository(
          ref.watch(fakeAdminDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiSpecialtyCorrectionRepository(dio);
    });
