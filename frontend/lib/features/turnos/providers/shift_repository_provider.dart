import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_shift_database.dart';
import '../repositories/fake_shift_repository.dart';
import '../repositories/shift_repository.dart';

final shiftRepositoryProvider = FutureProvider<ShiftRepository>((ref) async {
  if (ref.watch(useFakesProvider)) {
    return FakeShiftRepository(ref.watch(fakeShiftDatabaseProvider));
  }
  // TODO(turnos-paso-5): reemplazar por ApiShiftRepository(await
  // ref.watch(dioProvider.future)). Mientras tanto, con USE_FAKES en false la
  // consulta de turnos no funciona. Antes del PR este lanzamiento no puede
  // quedar en el código.
  throw UnimplementedError('Falta ApiShiftRepository (paso 5 de turnos).');
});
