import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../repositories/api_shift_statistics_repository.dart';
import '../repositories/fake_shift_statistics_repository.dart';
import '../repositories/shift_statistics_repository.dart';

final shiftStatisticsRepositoryProvider =
    FutureProvider<ShiftStatisticsRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeShiftStatisticsRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiShiftStatisticsRepository(dio);
    });
