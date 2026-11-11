import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../repositories/time_slot_statistics_repository.dart';

final timeSlotStatisticsRepositoryProvider =
    FutureProvider<TimeSlotStatisticsRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeTimeSlotStatisticsRepository();
      }
      return ApiTimeSlotStatisticsRepository(
        await ref.watch(dioProvider.future),
      );
    });
