import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_schedule_repository.dart';
import '../repositories/fake_schedule_repository.dart';
import '../repositories/schedule_repository.dart';
import 'schedules_today_provider.dart';

/// Punto único de inyección del repositorio de agendas. Con `USE_FAKES=true`
/// devuelve la implementación en memoria, con las consultas de la misma fecha
/// de hoy que usan los filtros.
final scheduleRepositoryProvider = FutureProvider<ScheduleRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return FakeScheduleRepository(today: ref.watch(schedulesTodayProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiScheduleRepository(dio);
});
