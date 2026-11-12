import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_clinic_correction_repository.dart';
import '../repositories/clinic_correction_repository.dart';
import '../repositories/fake_clinic_correction_repository.dart';

final clinicCorrectionRepositoryProvider =
    FutureProvider<ClinicCorrectionRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeClinicCorrectionRepository(
          ref.watch(fakeAdminDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiClinicCorrectionRepository(dio);
    });
