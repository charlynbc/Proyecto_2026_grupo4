import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_shift_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/shift_suspension_api_repository.dart';
import '../repositories/shift_suspension_fake_repository.dart';
import '../repositories/shift_suspension_repository.dart';
import 'suspension_clock_provider.dart';

/// Punto único de inyección del repositorio de suspensión de fechas. Con
/// `USE_FAKES=true` devuelve la implementación en memoria, sobre la misma base
/// de turnos que el listado.
final shiftSuspensionRepositoryProvider =
    FutureProvider<ShiftSuspensionRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeShiftSuspensionRepository(
          ref.watch(fakeShiftDatabaseProvider),
          today: ref.watch(suspensionClockProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiShiftSuspensionRepository(dio);
    });
