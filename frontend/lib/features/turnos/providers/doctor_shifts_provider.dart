import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor_shift.dart';
import 'doctor_shift_repository_provider.dart';

final doctorShiftsProvider =
    FutureProvider.autoDispose.family<List<DoctorShift>, DateTime>(
  (ref, date) async {
    final repository = await ref.watch(doctorShiftRepositoryProvider.future);
    return repository.getDoctorShifts(date: date);
  },
);
