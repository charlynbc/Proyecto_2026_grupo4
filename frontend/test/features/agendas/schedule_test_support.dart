import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_repository_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_refresh_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_today_provider.dart';
import 'package:agenda_medica/features/agendas/repositories/fake_schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/schedule_repository.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// Hoy en los ejemplos de la tarjeta.
final DateTime scheduleTestToday = DateTime.utc(2026, 10, 26);

/// El repositorio falso de agendas (sin latencia) que anota los filtros de
/// cada pedido. Con [failure] puesto falla, y con [gate] puesto los pedidos
/// quedan pendientes hasta completarlo.
class RecordingScheduleRepository implements ScheduleRepository {
  RecordingScheduleRepository()
    : _inner = FakeScheduleRepository(
        latency: Duration.zero,
        today: scheduleTestToday,
      );

  final FakeScheduleRepository _inner;
  final List<ScheduleFilters> calls = [];
  Object? failure;
  Completer<SchedulePage>? gate;

  @override
  Future<SchedulePage> search(ScheduleFilters filters) {
    calls.add(filters);
    final error = failure;
    if (error != null) return Future.error(error);
    return gate?.future ?? _inner.search(filters);
  }
}

/// Lo que hace falta para montar las pantallas de agendas: la fecha de hoy,
/// el repositorio de agendas y los médicos falsos del selector. El refresco
/// queda en 1 hora, para que ningún temporizador impida `pumpAndSettle`;
/// los tests del refresco pasan `pollInterval: null` para usar el de siempre.
List<Override> scheduleTestOverrides(
  RecordingScheduleRepository repository, {
  Duration? pollInterval = const Duration(hours: 1),
  ShiftRepositoryFactory? shiftRepository,
}) => [
  schedulesTodayProvider.overrideWithValue(scheduleTestToday),
  scheduleRepositoryProvider.overrideWith((ref) async => repository),
  shiftRepositoryProvider.overrideWith(
    (ref) async =>
        shiftRepository?.call() ??
        FakeShiftRepository(
          FakeShiftDatabase(FakeAdminDatabase(), seed: false),
          latency: Duration.zero,
        ),
  ),
  if (pollInterval != null)
    schedulesPollIntervalProvider.overrideWithValue(pollInterval),
];

/// Arma el repositorio de turnos que da los médicos del selector.
typedef ShiftRepositoryFactory = ShiftRepository Function();
