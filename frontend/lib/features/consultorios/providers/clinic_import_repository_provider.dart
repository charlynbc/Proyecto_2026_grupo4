import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_clinic_import_repository.dart';
import '../repositories/clinic_import_repository.dart';
import '../repositories/fake_clinic_import_repository.dart';

/// Punto único de inyección del repositorio de la carga masiva de
/// consultorios. Con `USE_FAKES=true` devuelve la implementación en memoria,
/// que comparte los consultorios con el resto de los repositories falsos del
/// administrador.
final clinicImportRepositoryProvider = FutureProvider<ClinicImportRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return FakeClinicImportRepository(ref.watch(fakeAdminDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiClinicImportRepository(dio);
});
