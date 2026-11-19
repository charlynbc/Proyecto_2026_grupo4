import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification_page.dart';
import 'package:agenda_medica/features/notificaciones/models/notification_query.dart';
import 'package:agenda_medica/features/notificaciones/providers/notification_list_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// La lista de avisos tiene que mostrar siempre lo último, igual que Mis
/// consultas: se vuelve a pedir al abrir la pantalla y al volver a verla (de
/// otra sección o del detalle de un aviso), conservando la página, y mientras
/// llega lo nuevo se sigue viendo lo anterior.

const _latency = Duration(milliseconds: 300);

/// Anota las páginas pedidas y tarda [_latency] en responder. El título del
/// aviso dice qué versión de la lista se recibió ("Versión 1", "Versión 2" y
/// así): 45 avisos en total, uno por página pedida.
class _Repository implements NotificationRepository {
  final requestedPages = <int>[];

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    requestedPages.add(query.page);
    final version = requestedPages.length;
    await Future<void>.delayed(_latency);
    return AppNotificationPage(
      items: [
        AppNotification(
          id: query.page + 1,
          type: 'AGENDA',
          title: 'Versión $version',
          consultaId: 9001,
          content: 'Contenido ${query.page + 1}',
          createdAt: DateTime.utc(2026, 10, 14, 13, 12),
        ),
      ],
      page: query.page,
      size: query.size,
      total: 45,
    );
  }
}

/// Deja pasar la latencia del repositorio (300 ms), en varios pasos: un pedido
/// que arranca un cuadro después de una transición (al volver a verse la
/// pantalla) agenda su espera recién en el paso siguiente.
Future<void> _wait(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

/// Avanza unos cuadros cortos, sin llegar a la latencia del repositorio.
Future<void> _framesShort(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<(ProviderContainer, _Repository)> _start(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
}) async {
  final repository = _Repository();
  final container = await pumpApp(
    tester,
    size: size,
    overrides: [
      notificationRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  final person = TestData.people.firstWhere(
    (p) => p.role == UserRole.socio.apiValue,
  );
  final auth = await container.read(authRepositoryProvider.future);
  final done = auth.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.socio,
  );
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
  return (container, repository);
}

Future<void> _openNotifications(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await goTo(tester, container, '/socio/avisos');
  await _wait(tester);
  expect(find.byType(NotificationsScreen), findsOneWidget);
}

void main() {
  testWidgets('al volver del detalle de un aviso la lista se pide de nuevo y '
      'muestra lo nuevo', (tester) async {
    final (container, repository) = await _start(tester);
    await _openNotifications(tester, container);
    expect(repository.requestedPages, [0]);
    expect(find.text('Versión 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-1')));
    await _wait(tester);
    expect(find.byType(AppointmentDetailScreen), findsOneWidget);
    expect(repository.requestedPages, [0], reason: 'abrir el detalle no pide');

    await tester.pageBack();
    await _wait(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(repository.requestedPages, [0, 0]);
    expect(find.text('Versión 2'), findsOneWidget);
    expect(find.text('Versión 1'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('al volver del detalle se conserva la página en que estaba', (
    tester,
  ) async {
    final (container, repository) = await _start(tester);
    await _openNotifications(tester, container);
    await tester.tap(find.byKey(const Key('notifications-next')));
    await _wait(tester);
    expect(repository.requestedPages, [0, 1]);
    expect(find.text('Página 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-2')));
    await _wait(tester);
    await tester.pageBack();
    await _wait(tester);

    expect(repository.requestedPages, [0, 1, 1]);
    expect(find.text('Página 2'), findsOneWidget);
    expect(find.text('Versión 3'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('al volver a la pestaña la lista anterior sigue a la vista '
      'mientras llega la nueva (sin ruedita)', (tester) async {
    final (container, repository) = await _start(tester);
    await _openNotifications(tester, container);
    await goTo(tester, container, '/socio/consultas');
    await _wait(tester);

    container.read(goRouterProvider).go('/socio/avisos');
    await _framesShort(tester);

    expect(repository.requestedPages, [0, 0]);
    expect(find.text('Versión 1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await _wait(tester);
    expect(find.text('Versión 2'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('al volver del detalle la lista anterior sigue a la vista '
      'mientras llega la nueva (sin ruedita)', (tester) async {
    final (container, repository) = await _start(tester);
    await _openNotifications(tester, container);
    await tester.tap(find.byKey(const Key('notification-1')));
    await _wait(tester);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 350));
    await _framesShort(tester);

    expect(repository.requestedPages, [0, 0]);
    expect(find.text('Versión 1'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await _wait(tester);
    expect(find.text('Versión 2'), findsOneWidget);
    await unmountApp(tester);
  });
}
