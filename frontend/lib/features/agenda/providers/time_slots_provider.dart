import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/time_slot.dart';
import 'agenda_repository_provider.dart';

/// `autoDispose`: al abandonar el provider (cambiar de día o salir de la
/// pantalla) no debe quedar cacheada una disponibilidad vieja. Al volver a
/// ese día se vuelve a pedir al backend en vez de mostrar horarios que ya
/// tomó otro socio.
final timeSlotsProvider = FutureProvider.autoDispose
    .family<List<TimeSlot>, ({int professionalId, DateTime day})>((
      ref,
      params,
    ) async {
      final repository = await ref.watch(agendaRepositoryProvider.future);
      return repository.listTimeSlots(
        professionalId: params.professionalId,
        day: params.day,
      );
    });
