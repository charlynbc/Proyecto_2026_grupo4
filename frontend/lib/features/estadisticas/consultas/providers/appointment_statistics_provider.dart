import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../repositories/api_appointment_statistics_repository.dart';
import '../repositories/appointment_statistics_repository.dart';
import '../repositories/fake_appointment_statistics_repository.dart';

final appointmentStatisticsRepositoryProvider =
    FutureProvider<AppointmentStatisticsRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeAppointmentStatisticsRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiAppointmentStatisticsRepository(dio);
    });
