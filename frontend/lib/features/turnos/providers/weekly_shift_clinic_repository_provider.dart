import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_shift_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_weekly_shift_clinic_repository.dart';
import '../repositories/fake_weekly_shift_clinic_repository.dart';
import '../repositories/weekly_shift_clinic_repository.dart';

/// Punto único de inyección del cambio de consultorio. Con `USE_FAKES=true`
/// devuelve la implementación en memoria.
final weeklyShiftClinicRepositoryProvider =
    FutureProvider<WeeklyShiftClinicRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeWeeklyShiftClinicRepository(
          ref.watch(fakeShiftDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiWeeklyShiftClinicRepository(dio);
    });
