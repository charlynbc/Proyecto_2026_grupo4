import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_staff_cancellation_repository.dart';
import '../repositories/fake_schedule_repository.dart';
import '../repositories/fake_staff_cancellation_repository.dart';
import '../repositories/staff_cancellation_repository.dart';
import 'schedule_repository_provider.dart';

final staffCancellationRepositoryProvider =
    FutureProvider<StaffCancellationRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        final schedules = await ref.watch(scheduleRepositoryProvider.future);
        return FakeStaffCancellationRepository(
          schedules as FakeScheduleRepository,
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiStaffCancellationRepository(dio);
    });
