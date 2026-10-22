import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/availability_query.dart';
import '../models/available_number.dart';
import 'agenda_repository_provider.dart';

/// Los números libres para [AvailabilityQuery]. `autoDispose`: al cambiar de
/// filtro o salir de la pantalla no debe quedar cacheada una disponibilidad
/// vieja que ya tomó otro socio.
final availabilityProvider = FutureProvider.autoDispose
    .family<List<AvailableNumber>, AvailabilityQuery>((ref, query) async {
      final repository = await ref.watch(agendaRepositoryProvider.future);
      return repository.listAvailability(query);
    });
