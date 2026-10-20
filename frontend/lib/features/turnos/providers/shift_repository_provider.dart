import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_shift_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_shift_repository.dart';
import '../repositories/fake_shift_repository.dart';
import '../repositories/shift_repository.dart';

/// Punto único de inyección del repositorio de turnos. Con `USE_FAKES=true`
/// devuelve la implementación en memoria.
final shiftRepositoryProvider = FutureProvider<ShiftRepository>((ref) async {
  if (ref.watch(useFakesProvider)) {
    return FakeShiftRepository(ref.watch(fakeShiftDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiShiftRepository(dio);
});
