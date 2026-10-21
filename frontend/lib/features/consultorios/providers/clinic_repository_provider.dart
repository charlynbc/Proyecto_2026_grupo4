import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_clinic_repository.dart';
import '../repositories/clinic_repository.dart';
import '../repositories/fake_clinic_repository.dart';

/// Punto único de inyección del repositorio de consultorios. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final clinicRepositoryProvider = FutureProvider<ClinicRepository>((ref) async {
  if (ref.watch(useFakesProvider)) {
    return FakeClinicRepository(ref.watch(fakeAdminDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiClinicRepository(dio);
});
