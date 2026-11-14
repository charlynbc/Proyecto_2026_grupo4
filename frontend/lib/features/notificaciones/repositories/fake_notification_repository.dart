import '../../../core/fakes/fake_notification_seed.dart';
import '../models/app_notification.dart';
import '../models/app_notification_page.dart';
import '../models/notification_query.dart';
import 'notification_repository.dart';

/// Implementación en memoria de [NotificationRepository] para
/// `USE_FAKES=true`. Ordena y pagina como el contrato: `creadaEn`
/// descendente, con el id mayor primero ante un empate, y valida `page` y
/// `size` con los mismos mensajes del servidor. Sin [seed] usa los avisos de
/// la socia de prueba (`kFakeNotificationSeed`).
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({
    this.latency = const Duration(milliseconds: 300),
    List<AppNotification>? seed,
  }) : _items = List.of(seed ?? kFakeNotificationSeed);

  final Duration latency;
  final List<AppNotification> _items;

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    await Future<void>.delayed(latency);
    if (query.size < 1 || query.size > 100) {
      throw const NotificationException(
        NotificationFailure.other,
        'size debe estar entre 1 y 100',
      );
    }
    if (query.page < 0) {
      throw const NotificationException(
        NotificationFailure.other,
        'page debe ser un entero mayor o igual a 0',
      );
    }
    final ordered = List.of(_items)
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate != 0 ? byDate : b.id.compareTo(a.id);
      });
    return AppNotificationPage(
      items: ordered.skip(query.page * query.size).take(query.size).toList(),
      page: query.page,
      size: query.size,
      total: ordered.length,
    );
  }
}
