import '../../../core/fakes/fake_notification_seed.dart';
import '../models/app_notification.dart';
import '../models/app_notification_page.dart';
import '../models/notification_query.dart';
import 'notification_repository.dart';

/// Implementación en memoria de [NotificationRepository] para
/// `USE_FAKES=true`. Aplica las reglas del servidor (contrato, fila 32):
///
/// - solo lista los avisos del socio autenticado ([currentCi]);
/// - no lista un recordatorio hasta que llega su hora (`scheduledFor`);
/// - ordena por `creadaEn` descendente, con el id mayor primero ante un
///   empate, y pagina con un `total` que cuenta solo lo que se lista;
/// - valida `page` y `size` con los mismos mensajes del servidor.
///
/// Sin [stored] ni [seed] usa los avisos de la socia de prueba, relativos a la
/// hora actual (`fakeNotificationSeed`). Con [seed] todos los avisos son del
/// socio autenticado y ninguno es diferido.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({
    this.latency = const Duration(milliseconds: 300),
    List<AppNotification>? seed,
    List<FakeStoredNotification>? stored,
    this.currentCi = kFakeMemberCi,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       _items = stored != null
           ? List.of(stored)
           : seed != null
           ? [for (final n in seed) FakeStoredNotification(n)]
           : fakeNotificationSeed((now ?? DateTime.now)());

  final Duration latency;

  /// La cédula del socio autenticado.
  final String currentCi;
  final DateTime Function() _now;
  final List<FakeStoredNotification> _items;

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    await Future<void>.delayed(latency);
    if (query.size < 1 || query.size > 100) {
      throw const NotificationException(
        NotificationFailure.validation,
        'size debe estar entre 1 y 100',
      );
    }
    if (query.page < 0) {
      throw const NotificationException(
        NotificationFailure.validation,
        'page debe ser un entero mayor o igual a 0',
      );
    }
    final now = _now();
    final ordered =
        [
          for (final item in _items)
            if (item.ownerCi == currentCi &&
                (item.scheduledFor == null || !item.scheduledFor!.isAfter(now)))
              item.notification,
        ]..sort((a, b) {
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
