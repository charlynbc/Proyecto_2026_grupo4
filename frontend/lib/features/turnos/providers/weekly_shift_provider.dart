import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weekly_shift.dart';
import 'shift_repository_provider.dart';

/// La configuración semanal con ese id.
///
/// Sin reintento automático (`retry` en `null`): la pantalla muestra el aviso
/// con "Reintentar" apenas falla, en vez de esperar los reintentos de Riverpod.
final weeklyShiftProvider = FutureProvider.autoDispose.family<WeeklyShift, int>(
  (ref, id) async {
    final repository = await ref.watch(shiftRepositoryProvider.future);
    return repository.getWeeklyShift(id);
  },
  retry: (_, _) => null,
);
