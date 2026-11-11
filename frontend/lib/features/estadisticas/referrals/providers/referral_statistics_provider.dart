import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/dio_client.dart';
import '../repositories/referral_statistics_repository.dart';

final referralStatisticsRepositoryProvider =
    FutureProvider<ReferralStatisticsRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeReferralStatisticsRepository();
      }
      return ApiReferralStatisticsRepository(
        await ref.watch(dioProvider.future),
      );
    });
