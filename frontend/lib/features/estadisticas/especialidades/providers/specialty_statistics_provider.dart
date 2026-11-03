import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../repositories/api_specialty_statistics_repository.dart';
import '../repositories/fake_specialty_statistics_repository.dart';
import '../repositories/specialty_statistics_repository.dart';

final specialtyStatisticsRepositoryProvider =
    FutureProvider<SpecialtyStatisticsRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeSpecialtyStatisticsRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiSpecialtyStatisticsRepository(dio);
    });
