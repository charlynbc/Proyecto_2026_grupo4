import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'schedules_page_provider.dart';

/// Cada cuánto se vuelve a consultar el servidor mientras se mira la agenda
/// (contrato #28: 15 segundos). Se sobrescribe en las pruebas.
final schedulesPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

/// El refresco automático de la agenda: mientras alguien la mira, cada
/// intervalo vuelve a pedir la página con los filtros actuales. La lista
/// anterior sigue a la vista mientras recarga (no hay parpadeo), y si el
/// pedido anterior sigue en vuelo no se hace otro.
///
/// Solo refresca con la pantalla a la vista. El shell mantiene montadas las
/// secciones ya visitadas pero fuera de la vista (con `TickerMode` apagado), y
/// Riverpod pausa las suscripciones de los widgets que están ahí: sin nadie
/// mirando, `onCancel` frena el temporizador y, al volver a la sección,
/// `onResume` pide la agenda enseguida (puede estar vieja) y retoma el ritmo.
///
/// Es `autoDispose`: al dejar de mirarlo se cancela el temporizador.
final schedulesRefreshProvider = Provider.autoDispose<void>((ref) {
  final interval = ref.watch(schedulesPollIntervalProvider);
  final page = ref.listen(schedulesPageProvider, (_, _) {});
  Timer? timer;

  void refresh() {
    if (page.read().isLoading) return;
    ref.invalidate(schedulesPageProvider);
  }

  void start() {
    timer?.cancel();
    timer = Timer.periodic(interval, (_) => refresh());
  }

  void stop() {
    timer?.cancel();
    timer = null;
  }

  start();
  ref.onCancel(stop);
  ref.onResume(() {
    start();
    // Riverpod no deja usar la `Ref` dentro de un ciclo de vida: el pedido se
    // difiere un instante.
    Future.microtask(() {
      if (ref.mounted) refresh();
    });
  });
  ref.onDispose(stop);
});
