import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_issued_referral_repository.dart';
import '../repositories/fake_issued_referral_repository.dart';
import '../repositories/issued_referral_repository.dart';

/// Punto único de inyección de los pases emitidos. Con `USE_FAKES=true`
/// devuelve la implementación en memoria.
final issuedReferralRepositoryProvider =
    FutureProvider<IssuedReferralRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeIssuedReferralRepository();
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiIssuedReferralRepository(dio);
    });
