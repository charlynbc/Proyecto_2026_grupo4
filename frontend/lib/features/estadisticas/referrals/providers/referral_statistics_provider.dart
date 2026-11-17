import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/fakes/fake_admin_database.dart';
import '../../../../core/network/dio_client.dart';
import '../repositories/referral_statistics_repository.dart';

final referralStatisticsRepositoryProvider =
    FutureProvider<ReferralStatisticsRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        // Las especialidades del catálogo del Fake de administración, el
        // mismo que ve el selector de origen.
        final database = ref.watch(fakeAdminDatabaseProvider);
        return FakeReferralStatisticsRepository(
          catalog: () => database.specialties,
        );
      }
      return ApiReferralStatisticsRepository(
        await ref.watch(dioProvider.future),
      );
    });
