import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification_page.dart';
import 'package:agenda_medica/features/notificaciones/models/notification_query.dart';
import 'package:agenda_medica/features/notificaciones/providers/notification_list_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/notification_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';

AppNotification _notification(int id, String title) => AppNotification(
  id: id,
  type: 'AGENDA',
  title: title,
  consultaId: 9001,
  content: 'Contenido $id',
  createdAt: DateTime.utc(2026, 10, 14, 13, 12),
);

/// Anota las páginas pedidas y responde según el número de pedido: el título
/// del aviso dice qué versión de la lista se recibió ("Versión 1", "Versión 2"
/// y así), y [failFirst] hace fallar el primer pedido.
class _Repository implements NotificationRepository {
  _Repository({this.failFirst = false});

  static const total = 45;
  final bool failFirst;
  final requestedPages = <int>[];

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    requestedPages.add(query.page);
    if (failFirst && requestedPages.length == 1) {
      throw const ApiException('No pudimos cargar tus avisos de prueba.');
    }
    return AppNotificationPage(
      items: [
        _notification(query.page + 1, 'Versión ${requestedPages.length}'),
      ],
      page: query.page,
      size: query.size,
      total: total,
    );
  }
}

Future<void> _loginAsSocio(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final person = TestData.people.firstWhere(
    (p) => p.role == UserRole.socio.apiValue,
  );
  final repository = await container.read(authRepositoryProvider.future);
  final done = repository.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.forRole(UserRole.socio),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  await done;
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<ProviderContainer> _start(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(900, 1800),
}) async {
  final container = await pumpApp(
    tester,
    size: size,
    overrides: [
      notificationRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  await _loginAsSocio(tester, container);
  return container;
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('abrir Avisos pide la lista una vez; salir y volver la pide de '
      'nuevo', (tester) async {
    final repository = _Repository();
    final container = await _start(tester, repository);

    await goTo(tester, container, '/socio/avisos');
    expect(repository.requestedPages, [0]);
    expect(find.text('Versión 1'), findsOneWidget);

    await goTo(tester, container, '/socio/consultas');
    expect(repository.requestedPages, [0], reason: 'al salir no pide nada');

    await goTo(tester, container, '/socio/avisos');
    expect(repository.requestedPages, [0, 0]);
    expect(find.text('Versión 2'), findsOneWidget);
    expect(find.text('Versión 1'), findsNothing);

    await goTo(tester, container, '/socio/cartelera');
    await goTo(tester, container, '/socio/avisos');
    expect(repository.requestedPages, [0, 0, 0]);
    expect(find.text('Versión 3'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('un error de carga no se queda: al volver se pide de nuevo', (
    tester,
  ) async {
    final repository = _Repository(failFirst: true);
    final container = await _start(tester, repository);

    await goTo(tester, container, '/socio/avisos');
    expect(find.byKey(const Key('notifications-error')), findsOneWidget);
    expect(repository.requestedPages, [0]);

    await goTo(tester, container, '/socio/consultas');
    await goTo(tester, container, '/socio/avisos');

    expect(repository.requestedPages, [0, 0]);
    expect(find.byKey(const Key('notifications-error')), findsNothing);
    expect(find.text('Versión 2'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('al volver se pide de nuevo la página en la que estaba', (
    tester,
  ) async {
    final repository = _Repository();
    final container = await _start(tester, repository);
    await goTo(tester, container, '/socio/avisos');
    await tester.tap(find.byKey(const Key('notifications-next')));
    await tester.pumpAndSettle();
    expect(repository.requestedPages, [0, 1]);
    expect(find.text('Versión 2'), findsOneWidget);

    await goTo(tester, container, '/socio/consultas');
    await goTo(tester, container, '/socio/avisos');

    expect(repository.requestedPages, [0, 1, 1]);
    expect(find.text('Versión 3'), findsOneWidget);
    expect(find.text('Versión 2'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('desde la barra inferior: tocar Avisos otra vez lo pide de '
      'nuevo', (tester) async {
    final repository = _Repository();
    final container = await _start(
      tester,
      repository,
      size: const Size(320, 800),
    );
    await goTo(tester, container, '/socio/disponibilidad');
    expect(repository.requestedPages, isEmpty);

    await tester.tap(find.text('Avisos'));
    await tester.pumpAndSettle();
    expect(repository.requestedPages, [0]);

    await tester.tap(find.text('Mis consultas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avisos'));
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [0, 0]);
    await unmountApp(tester);
  });

  testWidgets('tocar la pestaña Avisos estando en Avisos no pide de nuevo', (
    tester,
  ) async {
    final repository = _Repository();
    final container = await _start(
      tester,
      repository,
      size: const Size(320, 800),
    );
    await goTo(tester, container, '/socio/avisos');
    expect(repository.requestedPages, [0]);

    await tester.tap(find.text('Avisos').last);
    await tester.pumpAndSettle();

    expect(repository.requestedPages, [0]);
    await unmountApp(tester);
  });
}
