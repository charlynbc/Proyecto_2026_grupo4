import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/centered_content.dart';
import '../../../core/widgets/pagination_bar.dart';
import '../../agenda/screens/appointments_pending_screen.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/app_notification_page.dart';
import '../models/notification_query.dart';
import '../providers/notification_list_provider.dart';
import '../repositories/notification_repository.dart';
import '../widgets/notification_card.dart';

const String kNotificationsPath = '/socio/avisos';

/// Avisos del socio (RNF-23): la lista paginada de sus notificaciones internas,
/// la más reciente primero. Tocar un aviso abre la consulta a la que se
/// refiere.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _page = 0;

  NotificationQuery get _query => NotificationQuery(page: _page);

  @override
  Widget build(BuildContext context) {
    // Al volver a la pestaña de Avisos se empieza de nuevo por la página 1.
    ref.listen(notificationListReopenedProvider, (_, _) {
      if (_page != 0) setState(() => _page = 0);
    });
    final query = _query;
    final notifications = ref.watch(notificationListProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 700,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: notifications.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _loadError(error, query),
            data: _results,
          ),
        ),
      ),
    );
  }

  Widget _loadError(Object error, NotificationQuery query) {
    final message = switch (error) {
      NotificationException(failure: NotificationFailure.unauthenticated) =>
        'Tu sesión venció. Iniciá sesión nuevamente para ver tus avisos.',
      NotificationException(failure: NotificationFailure.forbidden) =>
        'Tu cuenta no tiene permiso para ver los avisos.',
      _ => apiMessageOf(error),
    };
    return Column(
      children: [
        Text(
          message,
          key: const Key('notifications-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => ref.invalidate(notificationListProvider(query)),
          child: const Text('Reintentar'),
        ),
      ],
    );
  }

  Widget _results(AppNotificationPage result) {
    if (result.items.isEmpty) {
      // Una página que ya no existe (por ejemplo, si se achicó la lista) deja
      // la fila de paginación para volver a la anterior.
      if (result.hasPrevious) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Esta página ya no tiene avisos.',
                  key: Key('notifications-empty-page'),
                ),
              ),
            ),
            _pagination(result),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No tenés notificaciones.',
            key: Key('notifications-empty'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${result.total} aviso${result.total == 1 ? '' : 's'}',
          key: const Key('notifications-total'),
        ),
        const SizedBox(height: 8),
        for (final notification in result.items)
          NotificationCard(
            notification: notification,
            onTap: () =>
                context.push('$kAppointmentsPath/${notification.consultaId}'),
          ),
        _pagination(result),
      ],
    );
  }

  Widget _pagination(AppNotificationPage result) {
    return PaginationBar(
      previousKey: const Key('notifications-previous'),
      nextKey: const Key('notifications-next'),
      label: 'Página ${result.page + 1}',
      hasPrevious: result.hasPrevious,
      hasNext: result.hasNext,
      onPrevious: () => setState(() => _page -= 1),
      onNext: () => setState(() => _page += 1),
    );
  }
}
