import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'schedules_page_provider.dart';

/// Cada cuánto se vuelve a consultar el servidor mientras se mira la agenda
/// (contrato #28: 15 segundos). Se sobrescribe en las pruebas.
final schedulesPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

/// El refresco automático de la agenda: mientras alguien lo mira, cada
/// intervalo vuelve a pedir la página con los filtros actuales. La lista
/// anterior sigue a la vista mientras recarga (no hay parpadeo), y si el
/// pedido anterior sigue en vuelo no se hace otro.
///
/// Es `autoDispose`: al dejar de mirarlo se cancela el temporizador.
final schedulesRefreshProvider = Provider.autoDispose<void>((ref) {
  final interval = ref.watch(schedulesPollIntervalProvider);
  final page = ref.listen(schedulesPageProvider, (_, _) {});
  final timer = Timer.periodic(interval, (_) {
    if (page.read().isLoading) return;
    ref.invalidate(schedulesPageProvider);
  });
  ref.onDispose(timer.cancel);
});
