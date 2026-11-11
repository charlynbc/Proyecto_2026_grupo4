import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../repositories/absence_statistics_repository.dart';
import '../repositories/api_absence_statistics_repository.dart';
import '../repositories/fake_absence_statistics_repository.dart';

final absenceStatisticsRepositoryProvider =
    FutureProvider<AbsenceStatisticsRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeAbsenceStatisticsRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiAbsenceStatisticsRepository(dio);
    });
