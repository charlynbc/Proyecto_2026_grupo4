import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_doctor_result_repository.dart';
import '../repositories/doctor_result_repository.dart';
import '../repositories/fake_doctor_result_repository.dart';

/// Punto único de inyección del repositorio del resultado de la consulta. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final doctorResultRepositoryProvider = FutureProvider<DoctorResultRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return FakeDoctorResultRepository(ref.watch(fakeAdminDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiDoctorResultRepository(dio);
});
