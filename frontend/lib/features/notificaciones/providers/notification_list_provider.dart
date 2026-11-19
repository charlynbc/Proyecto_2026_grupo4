import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/session_provider.dart';
import '../../auth/repositories/fake_auth_repository.dart';
import '../models/app_notification_page.dart';
import '../models/notification_query.dart';
import '../repositories/api_notification_repository.dart';
import '../repositories/fake_notification_repository.dart';
import '../repositories/notification_repository.dart';

/// Se incrementa para volver a pedir la lista de avisos (por ejemplo, al abrir
/// la pantalla de Avisos). No hay consulta periódica: el contrato decide que
/// la lista se pide al abrir la pantalla y al entrar a Mis consultas.
class NotificationListRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final notificationListRefreshProvider =
    NotifierProvider<NotificationListRefresh, int>(NotificationListRefresh.new);

/// Se incrementa al volver a la pestaña de Avisos: la pantalla vuelve a la
/// primera página.
class NotificationListReopened extends Notifier<int> {
  @override
  int build() => 0;

  void reopened() => state++;
}

final notificationListReopenedProvider =
    NotifierProvider<NotificationListReopened, int>(
      NotificationListReopened.new,
    );

final notificationRepositoryProvider = FutureProvider<NotificationRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    // El Fake, como el servidor, lista solo los avisos de quien ingresó.
    final ci = fakeCiOfToken(
      ref.watch(sessionProvider.select((session) => session.accessToken)),
    );
    return FakeNotificationRepository(currentCi: ci ?? '');
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiNotificationRepository(dio);
});

/// Vuelve a pedir la lista cuando la pantalla que la mira vuelve a verse.
///
/// El shell mantiene montadas las secciones ya visitadas y la lista queda
/// debajo del detalle de un aviso: mientras no se ve, Riverpod pausa sus
/// suscripciones pero no descarta el provider, y lo que mostraba puede estar
/// viejo. Al volver a verse (`onResume`) se mueve el contador de refresco y la
/// página que se está mirando se pide de nuevo; mientras llega, la pantalla
/// sigue mostrando lo anterior.
///
/// Riverpod no deja usar la `Ref` dentro de un ciclo de vida, y al reabrir la
/// pestaña la pantalla todavía puede estar cambiando de página: el pedido se
/// difiere hasta el fin del cuadro siguiente, y si para entonces esa página ya
/// no se mira (`ref.mounted` en falso) no se pide.
void _refetchWhenVisibleAgain(Ref ref) {
  ref.onResume(() {
    Future.microtask(() async {
      await WidgetsBinding.instance.endOfFrame;
      if (ref.mounted) {
        ref.read(notificationListRefreshProvider.notifier).refresh();
      }
    });
  });
}

/// La página de avisos que corresponde a [NotificationQuery].
///
/// Se libera cuando la pantalla deja de mirar esa página (`autoDispose`): al
/// volver a una página que se dejó, se pide de nuevo en vez de mostrar la
/// guardada.
///
/// Sin reintento automático (`retry` en `null`): Riverpod 3 reintenta solo
/// hasta 10 veces, con esperas de 0,2 a 6,4 s, y durante ese tiempo la
/// pantalla seguiría mostrando el cargando en vez del aviso con "Reintentar".
final notificationListProvider = FutureProvider.autoDispose
    .family<AppNotificationPage, NotificationQuery>((ref, query) async {
      ref.watch(notificationListRefreshProvider);
      _refetchWhenVisibleAgain(ref);
      final repository = await ref.watch(notificationRepositoryProvider.future);
      return repository.list(query);
    }, retry: (_, _) => null);
