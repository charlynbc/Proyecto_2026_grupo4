import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor.dart';
import 'shift_repository_provider.dart';

/// Los médicos activos, para los selectores de médico.
final doctorsProvider = FutureProvider.autoDispose<List<Doctor>>((ref) async {
  final repository = await ref.watch(shiftRepositoryProvider.future);
  return repository.listDoctors();
});
