import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_specialty_import_repository.dart';
import '../repositories/fake_specialty_import_repository.dart';
import '../repositories/specialty_import_repository.dart';

/// Punto único de inyección del repositorio de la carga masiva de
/// especialidades. Con `USE_FAKES=true` devuelve la implementación en
/// memoria, que comparte el catálogo con el resto de los repositories falsos
/// del administrador.
final specialtyImportRepositoryProvider =
    FutureProvider<SpecialtyImportRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeSpecialtyImportRepository(
          ref.watch(fakeAdminDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiSpecialtyImportRepository(dio);
    });
