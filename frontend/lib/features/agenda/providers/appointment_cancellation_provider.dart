import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_appointment_cancellation_repository.dart';
import '../repositories/appointment_cancellation_repository.dart';
import '../repositories/fake_appointment_cancellation_repository.dart';

final appointmentCancellationRepositoryProvider =
    FutureProvider<AppointmentCancellationRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeAppointmentCancellationRepository(
          ref.watch(fakeDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiAppointmentCancellationRepository(dio);
    });
