import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_doctor_shift_repository.dart';
import '../repositories/doctor_shift_repository.dart';
import '../repositories/fake_doctor_shift_repository.dart';

final doctorShiftRepositoryProvider = FutureProvider<DoctorShiftRepository>(
  (ref) async {
    if (ref.watch(useFakesProvider)) {
      return FakeDoctorShiftRepository();
    }
    final dio = await ref.watch(dioProvider.future);
    return ApiDoctorShiftRepository(dio);
  },
);
