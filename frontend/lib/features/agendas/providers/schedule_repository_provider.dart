import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_schedule_repository.dart';
import '../repositories/fake_schedule_repository.dart';
import '../repositories/schedule_repository.dart';
import 'schedules_clock_provider.dart';

/// Punto único de inyección del repositorio de agendas. Con `USE_FAKES=true`
/// devuelve la implementación en memoria, con las consultas de hoy y las dos
/// agendadas puestas respecto del reloj (una cancelable y otra no).
final scheduleRepositoryProvider = FutureProvider<ScheduleRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return FakeScheduleRepository.relativeTo(
      clock: ref.watch(schedulesClockProvider),
    );
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiScheduleRepository(dio);
});
