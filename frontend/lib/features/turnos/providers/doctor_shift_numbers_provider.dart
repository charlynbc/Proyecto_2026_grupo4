import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor_shift_number.dart';
import 'doctor_shift_repository_provider.dart';

final doctorShiftNumbersProvider =
    FutureProvider.autoDispose.family<DoctorShiftNumbersResponse, int>(
  (ref, shiftId) async {
    final repository = await ref.watch(doctorShiftRepositoryProvider.future);
    return repository.getDoctorShiftNumbers(shiftId: shiftId);
  },
);
