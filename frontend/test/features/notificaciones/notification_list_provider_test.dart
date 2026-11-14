import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification_page.dart';
import 'package:agenda_medica/features/notificaciones/models/notification_query.dart';
import 'package:agenda_medica/features/notificaciones/providers/notification_list_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/repositories/notification_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Falla siempre y cuenta cuántas veces se le pidió la lista.
class _FailingRepository implements NotificationRepository {
  int calls = 0;

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    calls++;
    throw const ApiException('No se pudo cargar de prueba.');
  }
}

/// Responde una página vacía y cuenta los pedidos.
class _CountingRepository implements NotificationRepository {
  int calls = 0;

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    calls++;
    return AppNotificationPage(
      items: const [],
      page: query.page,
      size: query.size,
      total: 0,
    );
  }
}

void main() {
  // Riverpod 3 reintenta solo los providers que fallan (el primer reintento a
  // los 200 ms) y mientras tanto el estado es "cargando": la pantalla no
  // llegaría a mostrar el error. El provider de la lista no debe reintentar.
  testWidgets('una falla del repositorio es un AsyncError enseguida y se '
      'pide una sola vez', (tester) async {
    final repository = _FailingRepository();
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    const query = NotificationQuery();
    container.listen(
      notificationListProvider(query),
      (_, _) {},
      onError: (_, _) {},
    );

    await tester.pump(const Duration(milliseconds: 1));
    final state = container.read(notificationListProvider(query));

    expect(state, isA<AsyncError<AppNotificationPage>>());
    expect(state.isLoading, isFalse);
    expect(state.retrying, isFalse);
    expect(repository.calls, 1);

    // Más tiempo que el primer reintento de Riverpod: no vuelve a pedir.
    await tester.pump(const Duration(seconds: 2));

    expect(container.read(notificationListProvider(query)), isA<AsyncError>());
    expect(repository.calls, 1);
  });

  testWidgets('sin consulta periódica: pasado el tiempo no vuelve a pedir '
      'la lista', (tester) async {
    final repository = _CountingRepository();
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    const query = NotificationQuery();
    container.listen(notificationListProvider(query), (_, _) {});

    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.calls, 1);

    await tester.pump(const Duration(minutes: 5));

    expect(repository.calls, 1);
  });

  testWidgets('cada página distinta es un pedido distinto', (tester) async {
    final repository = _CountingRepository();
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      notificationListProvider(const NotificationQuery()),
      (_, _) {},
    );
    container.listen(
      notificationListProvider(const NotificationQuery(page: 1)),
      (_, _) {},
    );

    await tester.pump(const Duration(milliseconds: 1));

    expect(repository.calls, 2);
  });

  testWidgets('el contador de refresco vuelve a pedir la lista', (
    tester,
  ) async {
    final repository = _CountingRepository();
    final container = ProviderContainer(
      overrides: [
        notificationRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    const query = NotificationQuery();
    container.listen(notificationListProvider(query), (_, _) {});
    await tester.pump(const Duration(milliseconds: 1));
    expect(repository.calls, 1);

    container.read(notificationListRefreshProvider.notifier).refresh();
    await tester.pump(const Duration(milliseconds: 1));

    expect(repository.calls, 2);
  });

  testWidgets('con USE_FAKES el repositorio es el falso', (tester) async {
    final container = ProviderContainer(
      overrides: [useFakesProvider.overrideWithValue(true)],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      notificationRepositoryProvider.future,
    );

    expect(repository, isA<FakeNotificationRepository>());
  });
}
