import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
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

final notificationRepositoryProvider = FutureProvider<NotificationRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) return FakeNotificationRepository();
  final dio = await ref.watch(dioProvider.future);
  return ApiNotificationRepository(dio);
});

/// La página de avisos que corresponde a [NotificationQuery].
///
/// Sin reintento automático (`retry` en `null`): Riverpod 3 reintenta solo
/// hasta 10 veces, con esperas de 0,2 a 6,4 s, y durante ese tiempo la
/// pantalla seguiría mostrando el cargando en vez del aviso con "Reintentar".
final notificationListProvider =
    FutureProvider.family<AppNotificationPage, NotificationQuery>((
      ref,
      query,
    ) async {
      ref.watch(notificationListRefreshProvider);
      final repository = await ref.watch(notificationRepositoryProvider.future);
      return repository.list(query);
    }, retry: (_, _) => null);
