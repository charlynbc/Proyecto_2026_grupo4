import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_doctor_cancellation_repository.dart';
import '../repositories/doctor_cancellation_repository.dart';
import '../repositories/fake_doctor_cancellation_repository.dart';
import 'doctor_agenda_controller.dart';

/// Punto único de inyección de la cancelación. Con `USE_FAKES=true` comparte
/// el turno falso de la agenda, así la lista ve el número liberado.
final doctorCancellationRepositoryProvider =
    FutureProvider<DoctorCancellationRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeDoctorCancellationRepository(
          ref.watch(fakeDoctorShiftRepositoryProvider),
          clock: ref.watch(fakeAdminDatabaseProvider).clock,
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiDoctorCancellationRepository(dio);
    });
