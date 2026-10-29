import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_shift_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_reinstatement_repository.dart';
import '../repositories/fake_reinstatement_repository.dart';
import '../repositories/shift_reinstatement_repository.dart';

/// Punto único de inyección del repositorio de rehabilitación. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final reinstatementRepositoryProvider =
    FutureProvider<ShiftReinstatementRepository>((ref) async {
      if (ref.watch(useFakesProvider)) {
        return FakeShiftReinstatementRepository(
          ref.watch(fakeShiftDatabaseProvider),
        );
      }
      final dio = await ref.watch(dioProvider.future);
      return ApiShiftReinstatementRepository(dio);
    });
