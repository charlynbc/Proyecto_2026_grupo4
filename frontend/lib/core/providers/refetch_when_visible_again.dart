import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ejecuta [refetch] cuando la pantalla que mira a [ref] vuelve a verse.
///
/// El shell conserva montadas las secciones ya visitadas, y una ruta encima
/// tapa a la de abajo. Riverpod pausa esas suscripciones y las reanuda con
/// `onResume`. La pestaña del navegador o la app, al volver a primer plano,
/// no pasan por ahí: lo escucha un [AppLifecycleListener]. Si el provider
/// estaba pausado, Riverpod deja el pedido hasta que vuelve a verse, y
/// `onResume` lo hace una sola vez.
///
/// Riverpod no deja usar la [Ref] dentro del ciclo de vida: el pedido se
/// difiere un instante. Al descartar el provider se suelta el listener.
void refetchWhenVisibleAgain(Ref ref, void Function() refetch) {
  void refresh() {
    Future.microtask(() {
      if (ref.mounted) refetch();
    });
  }

  ref.onResume(refresh);
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (ref.mounted) refresh();
    },
  );
  ref.onDispose(lifecycle.dispose);
}
