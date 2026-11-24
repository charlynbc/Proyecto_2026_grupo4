import 'package:agenda_medica/core/config/app_locale.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/widgets/pagination_bar.dart';
import 'package:agenda_medica/features/historia_clinica/screens/medical_history_screen.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification.dart';
import 'package:agenda_medica/features/notificaciones/models/app_notification_page.dart';
import 'package:agenda_medica/features/notificaciones/models/notification_query.dart';
import 'package:agenda_medica/features/notificaciones/providers/notification_list_provider.dart';
import 'package:agenda_medica/features/notificaciones/repositories/notification_repository.dart';
import 'package:agenda_medica/features/notificaciones/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pager_layout.dart';

AppNotification _notification(
  int id,
  String type,
  String title,
  int? consultaId,
  String content,
  DateTime createdAt, {
  int? atencionId,
}) => AppNotification(
  id: id,
  type: type,
  title: title,
  consultaId: consultaId,
  atencionId: atencionId,
  content: content,
  createdAt: createdAt,
);

// 14/10/2026 10:12, 14/10/2026 22:30 (el instante es del día 15 en UTC) y
// 16/10/2026 11:20, en hora de Uruguay.
final _agenda = _notification(
  15003,
  'AGENDA',
  'Consulta agendada',
  9001,
  'Tu consulta quedó agendada para el 20/10/2026 a las 09:20.',
  DateTime.utc(2026, 10, 14, 13, 12),
);
final _cancelacion = _notification(
  15002,
  'CANCELACION',
  'Consulta cancelada',
  9002,
  'Tu consulta del 21/10/2026 fue cancelada a tu solicitud.',
  DateTime.utc(2026, 10, 15, 1, 30),
);
final _suspension = _notification(
  15001,
  'SUSPENSION',
  'Turno suspendido',
  9003,
  'Tu consulta del 22/10/2026 fue cancelada por la institución.',
  DateTime.utc(2026, 10, 16, 14, 20),
);

/// Responde las páginas que se le dan (las que no figuran, vacías con total
/// 0) y anota las páginas pedidas, en orden.
class _Repository implements NotificationRepository {
  _Repository({this.pages = const {}, this.error, this.failFirst = false});

  final Map<int, ({List<AppNotification> items, int total})> pages;
  final Object? error;
  final bool failFirst;
  final requestedPages = <int>[];
  bool _failed = false;

  @override
  Future<AppNotificationPage> list(NotificationQuery query) async {
    requestedPages.add(query.page);
    if (error != null) throw error!;
    if (failFirst && !_failed) {
      _failed = true;
      throw const ApiException('No pudimos cargar tus avisos de prueba.');
    }
    final page =
        pages[query.page] ?? (items: const <AppNotification>[], total: 0);
    return AppNotificationPage(
      items: page.items,
      page: query.page,
      size: query.size,
      total: page.total,
    );
  }
}

_Repository _one(List<AppNotification> items) =>
    _Repository(pages: {0: (items: items, total: items.length)});

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(900, 1800),
  double textScale = 1,
  GoRouter? router,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = router == null
      ? MaterialApp(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kLocalizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const NotificationsScreen(),
        )
      : MaterialApp.router(
          locale: kAppLocale,
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kLocalizationsDelegates,
          routerConfig: router,
        );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationRepositoryProvider.overrideWith((ref) async => repository),
      ],
      child: app,
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router() => GoRouter(
  initialLocation: '/socio/avisos',
  routes: [
    GoRoute(
      path: '/socio/avisos',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/socio/consultas/:id',
      builder: (context, state) =>
          Scaffold(body: Text('Detalle ${state.pathParameters['id']}')),
    ),
    GoRoute(
      path: '/socio/historia',
      builder: (context, state) =>
          const Scaffold(body: Text('Lista de historia clínica')),
    ),
    GoRoute(
      path: '/socio/historia/:id',
      builder: (context, state) =>
          Scaffold(body: Text('Atención ${state.pathParameters['id']}')),
    ),
  ],
);

void main() {
  testWidgets('muestra cada aviso con título, contenido y fecha y hora de '
      'Uruguay', (tester) async {
    await _pump(tester, _one([_agenda, _cancelacion, _suspension]));

    expect(find.text('Consulta agendada'), findsOneWidget);
    expect(
      find.text('Tu consulta quedó agendada para el 20/10/2026 a las 09:20.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('notification-date-15003')))
          .data,
      '14/10/2026 10:12',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('notification-date-15002')))
          .data,
      '14/10/2026 22:30',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('notification-date-15001')))
          .data,
      '16/10/2026 11:20',
    );
    expect(find.text('Consulta cancelada'), findsOneWidget);
    expect(find.text('Turno suspendido'), findsOneWidget);
    expect(find.byKey(const Key('notifications-empty')), findsNothing);
    expect(find.byKey(const Key('notifications-error')), findsNothing);
  });

  testWidgets('los avisos se ven en el orden en que los manda el servidor', (
    tester,
  ) async {
    // El servidor manda el más nuevo primero: el cliente no reordena.
    final items = [
      _notification(30, 'AGENDA', 'c', 1, 'c', DateTime.utc(2026, 10, 3)),
      _notification(20, 'AGENDA', 'b', 1, 'c', DateTime.utc(2026, 10, 2)),
      _notification(10, 'AGENDA', 'a', 1, 'c', DateTime.utc(2026, 10, 1)),
    ];
    await _pump(tester, _one(items));

    final tops = [
      for (final id in [30, 20, 10])
        tester.getTopLeft(find.byKey(Key('notification-$id'))).dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
  });

  testWidgets('el total va en plural', (tester) async {
    await _pump(tester, _one([_agenda, _cancelacion, _suspension]));

    expect(
      tester.widget<Text>(find.byKey(const Key('notifications-total'))).data,
      '3 avisos',
    );
  });

  testWidgets('el total va en singular con un solo aviso', (tester) async {
    await _pump(tester, _one([_agenda]));

    expect(
      tester.widget<Text>(find.byKey(const Key('notifications-total'))).data,
      '1 aviso',
    );
  });

  testWidgets('cada tipo tiene su ícono, sin descripción propia del cliente', (
    tester,
  ) async {
    final items = [
      _notification(1, 'AGENDA', 'a', 1, 'c', DateTime.utc(2026, 10, 1)),
      _notification(2, 'CANCELACION', 'b', 1, 'c', DateTime.utc(2026, 10, 2)),
      _notification(3, 'SUSPENSION', 'c', 1, 'c', DateTime.utc(2026, 10, 3)),
      _notification(
        4,
        'HISTORIA_ACTUALIZADA',
        'd',
        1,
        'c',
        DateTime.utc(2026, 10, 4),
      ),
      _notification(5, 'RECORDATORIO', 'e', 1, 'c', DateTime.utc(2026, 10, 5)),
      _notification(6, 'OTRO_TIPO', 'f', 1, 'c', DateTime.utc(2026, 10, 6)),
    ];
    await _pump(tester, _one(items));

    // El título lo arma el servidor; el cliente no lo reconstruye por tipo,
    // ni siquiera como descripción del ícono.
    final expected = {
      1: Icons.event_available,
      2: Icons.event_busy,
      3: Icons.pause_circle_outline,
      4: Icons.medical_information_outlined,
      5: Icons.alarm,
      6: Icons.notifications_none,
    };
    for (final MapEntry(key: id, value: icon) in expected.entries) {
      final widget = tester.widget<Icon>(
        find.byKey(Key('notification-icon-$id')),
      );
      expect(widget.icon, icon, reason: 'aviso $id');
      expect(widget.semanticLabel, isNull, reason: 'aviso $id');
    }
  });

  testWidgets('sin avisos muestra el texto de vacío y no el paginador', (
    tester,
  ) async {
    await _pump(tester, _one(const []));

    expect(
      tester.widget<Text>(find.byKey(const Key('notifications-empty'))).data,
      'No tenés notificaciones.',
    );
    expect(find.byType(PaginationBar), findsNothing);
    expect(find.byKey(const Key('notifications-total')), findsNothing);
  });

  group('error de carga', () {
    testWidgets('muestra el mensaje y Reintentar vuelve a pedir la lista', (
      tester,
    ) async {
      final repository = _Repository(
        pages: {
          0: (items: [_agenda], total: 1),
        },
        failFirst: true,
      );
      await _pump(tester, repository);

      expect(
        tester.widget<Text>(find.byKey(const Key('notifications-error'))).data,
        'No pudimos cargar tus avisos de prueba.',
      );
      expect(find.text('Consulta agendada'), findsNothing);
      expect(repository.requestedPages, [0]);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repository.requestedPages, [0, 0]);
      expect(find.byKey(const Key('notifications-error')), findsNothing);
      expect(find.text('Consulta agendada'), findsOneWidget);
    });

    testWidgets('una sesión vencida lo dice con palabras de todos los días', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(
          error: const NotificationException(
            NotificationFailure.unauthenticated,
            'respuesta del servidor',
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.byKey(const Key('notifications-error'))).data,
        'Tu sesión venció. Iniciá sesión nuevamente para ver tus avisos.',
      );
    });

    testWidgets('una cuenta sin permiso lo dice', (tester) async {
      await _pump(
        tester,
        _Repository(
          error: const NotificationException(
            NotificationFailure.forbidden,
            'respuesta del servidor',
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.byKey(const Key('notifications-error'))).data,
        'Tu cuenta no tiene permiso para ver los avisos.',
      );
    });

    testWidgets('un 400 de validación no muestra el mensaje técnico del '
        'servidor', (tester) async {
      await _pump(
        tester,
        _Repository(
          error: const NotificationException(
            NotificationFailure.validation,
            'size debe estar entre 1 y 100',
          ),
        ),
      );

      expect(
        tester.widget<Text>(find.byKey(const Key('notifications-error'))).data,
        'No se pudieron cargar los avisos. Probá de nuevo más tarde.',
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('otra falla muestra el mensaje que trae', (tester) async {
      await _pump(
        tester,
        _Repository(error: const ApiException('Mensaje del servidor.')),
      );

      expect(
        tester.widget<Text>(find.byKey(const Key('notifications-error'))).data,
        'Mensaje del servidor.',
      );
    });
  });

  group('paginación', () {
    final pages = {
      0: (items: [_agenda], total: 45),
      1: (items: [_suspension], total: 45),
      2: (items: const <AppNotification>[], total: 45),
    };

    testWidgets('Siguiente y Anterior piden la página que corresponde', (
      tester,
    ) async {
      final repository = _Repository(pages: pages);
      await _pump(tester, repository);

      expect(find.text('Página 1'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('notifications-previous')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('notifications-next')));
      await tester.pumpAndSettle();

      expect(repository.requestedPages, [0, 1]);
      expect(find.text('Página 2'), findsOneWidget);
      expect(find.text('Turno suspendido'), findsOneWidget);
      expect(find.text('Consulta agendada'), findsNothing);

      await tester.tap(find.byKey(const Key('notifications-previous')));
      await tester.pumpAndSettle();

      expect(find.text('Página 1'), findsOneWidget);
      expect(find.text('Consulta agendada'), findsOneWidget);
    });

    testWidgets('una página que ya no tiene avisos deja volver a la anterior', (
      tester,
    ) async {
      await _pump(tester, _Repository(pages: pages));
      await tester.tap(find.byKey(const Key('notifications-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notifications-next')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('notifications-empty-page')))
            .data,
        'Esta página ya no tiene avisos.',
      );
      expect(find.byKey(const Key('notifications-previous')), findsOneWidget);
    });
  });

  group('detalle de la consulta', () {
    testWidgets('tocar un aviso abre la consulta con el id de la consulta, no '
        'el del aviso', (tester) async {
      await _pump(tester, _one([_agenda, _cancelacion]), router: _router());

      await tester.tap(find.byKey(const Key('notification-15002')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle 9002'), findsOneWidget);
      expect(find.text('Detalle 15002'), findsNothing);
    });

    testWidgets('cada aviso lleva a su propia consulta', (tester) async {
      await _pump(tester, _one([_agenda, _suspension]), router: _router());

      await tester.tap(find.byKey(const Key('notification-15003')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle 9001'), findsOneWidget);
    });
  });

  group('aviso sin consulta', () {
    final sinConsulta = _notification(
      15040,
      'AGENDA',
      'Consulta agendada',
      null,
      'Aviso que no cuelga de ninguna consulta.',
      DateTime.utc(2026, 10, 17, 14),
    );

    ListTile tileOf(WidgetTester tester, int id) =>
        tester.widget<ListTile>(find.byKey(Key('notification-$id')));

    testWidgets('se muestra completo, con título, contenido y fecha', (
      tester,
    ) async {
      await _pump(tester, _one([sinConsulta]), router: _router());

      expect(find.text('Consulta agendada'), findsOneWidget);
      expect(
        find.text('Aviso que no cuelga de ninguna consulta.'),
        findsOneWidget,
      );
      expect(find.text('17/10/2026 11:00'), findsOneWidget);
    });

    testWidgets('tocarlo no navega a ningún lado', (tester) async {
      await _pump(tester, _one([sinConsulta]), router: _router());

      await tester.tap(find.byKey(const Key('notification-15040')));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.textContaining('Detalle'), findsNothing);
    });

    testWidgets('no es tocable y no muestra la flecha de abrir', (
      tester,
    ) async {
      await _pump(tester, _one([sinConsulta]), router: _router());

      expect(tileOf(tester, 15040).onTap, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('notification-15040')),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNothing,
      );
    });

    testWidgets('los avisos con consulta siguen siendo tocables y con '
        'flecha', (tester) async {
      await _pump(tester, _one([sinConsulta, _agenda]), router: _router());

      expect(tileOf(tester, 15003).onTap, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('notification-15003')),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uno de historia actualizada sigue abriendo la historia '
        'clínica aunque no traiga consulta', (tester) async {
      final historia = _notification(
        15041,
        'HISTORIA_ACTUALIZADA',
        'Historia clínica actualizada',
        null,
        'Tu historia clínica fue actualizada.',
        DateTime.utc(2026, 10, 17, 15),
      );
      await _pump(tester, _one([historia]), router: _router());

      await tester.tap(find.byKey(const Key('notification-15041')));
      await tester.pumpAndSettle();

      expect(find.text('Lista de historia clínica'), findsOneWidget);
    });
  });

  group('destino según el tipo de aviso', () {
    final createdAt = DateTime.utc(2026, 10, 16, 14, 20);

    test('la ruta de la historia clínica es /socio/historia', () {
      expect(kMedicalHistoryPath, '/socio/historia');
    });

    testWidgets('un aviso de historia actualizada abre la lista de la '
        'historia clínica y al retroceder vuelve a Avisos', (tester) async {
      final historia = _notification(
        15020,
        'HISTORIA_ACTUALIZADA',
        'Historia clínica actualizada',
        9110,
        'Tu historia clínica fue actualizada.',
        createdAt,
      );
      final router = _router();
      await _pump(tester, _one([historia]), router: router);

      await tester.tap(find.byKey(const Key('notification-15020')));
      await tester.pumpAndSettle();

      expect(find.text('Lista de historia clínica'), findsOneWidget);
      expect(find.text('Detalle 9110'), findsNothing);
      expect(find.byType(NotificationsScreen), findsNothing);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Lista de historia clínica'), findsNothing);
    });

    testWidgets('un aviso de historia actualizada con atencionId 4100 abre el '
        'detalle de esa atención y no la lista', (tester) async {
      final historia = _notification(
        15021,
        'HISTORIA_ACTUALIZADA',
        'Historia clínica actualizada',
        9110,
        'Tu historia clínica fue actualizada.',
        createdAt,
        atencionId: 4100,
      );
      final router = _router();
      await _pump(tester, _one([historia]), router: router);

      await tester.tap(find.byKey(const Key('notification-15021')));
      await tester.pumpAndSettle();

      expect(find.text('Atención 4100'), findsOneWidget);
      expect(find.text('Lista de historia clínica'), findsNothing);
      expect(find.text('Detalle 9110'), findsNothing);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen), findsOneWidget);
      expect(find.text('Atención 4100'), findsNothing);
    });

    testWidgets('un aviso que no es de historia ignora el atencionId y abre la '
        'consulta', (tester) async {
      final agenda = _notification(
        15022,
        'AGENDA',
        'Consulta agendada',
        9105,
        'Contenido de prueba.',
        createdAt,
        atencionId: 4100,
      );
      await _pump(tester, _one([agenda]), router: _router());

      await tester.tap(find.byKey(const Key('notification-15022')));
      await tester.pumpAndSettle();

      expect(find.text('Detalle 9105'), findsOneWidget);
      expect(find.text('Atención 4100'), findsNothing);
    });

    for (final (type, title, consultaId) in [
      ('AGENDA', 'Consulta agendada', 9101),
      ('CANCELACION', 'Consulta cancelada', 9102),
      ('SUSPENSION', 'Turno suspendido', 9103),
      ('RECORDATORIO', 'Recordatorio de consulta', 9104),
    ]) {
      testWidgets('un aviso de tipo $type abre el detalle de la consulta '
          '$consultaId', (tester) async {
        final aviso = _notification(
          15030,
          type,
          title,
          consultaId,
          'Contenido de prueba.',
          createdAt,
        );
        await _pump(tester, _one([aviso]), router: _router());

        await tester.tap(find.byKey(const Key('notification-15030')));
        await tester.pumpAndSettle();

        expect(find.text('Detalle $consultaId'), findsOneWidget);
        expect(find.text('Lista de historia clínica'), findsNothing);
      });
    }
  });

  group('a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    final long = _notification(
      15010,
      'HISTORIA_ACTUALIZADA',
      'Historia clínica actualizada',
      9010,
      'Tu consulta del 20/10/2026 fue cancelada por la institución. '
          'Horario: 09:20 a 09:40 (número 2). Motivo: el médico no puede '
          'atender ese día por una licencia.',
      DateTime.utc(2026, 10, 16, 14, 20),
    );

    testWidgets(
      'con texto al doble la lista no desborda y las tarjetas entran',
      (tester) async {
        await _pump(
          tester,
          _one([long, _agenda, _cancelacion]),
          size: const Size(320, 2400),
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
        for (final id in [15010, 15003, 15002]) {
          final rect = tester.getRect(find.byKey(Key('notification-$id')));
          expect(rect.left, greaterThanOrEqualTo(0), reason: 'aviso $id');
          expect(rect.right, lessThanOrEqualTo(320), reason: 'aviso $id');
        }
        // El texto largo no se corta con puntos suspensivos.
        final content = tester.widget<Text>(
          find.byKey(const Key('notification-content-15010')),
        );
        expect(content.overflow, isNot(TextOverflow.ellipsis));
        expect(content.maxLines, isNull);
      },
    );

    testWidgets('con texto al doble el paginador no desborda y queda dentro', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(
          pages: {
            0: (items: [long], total: 25),
          },
        ),
        size: const Size(320, 2400),
        textScale: 2,
      );
      await tester.ensureVisible(find.byKey(const Key('notifications-next')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final key in ['notifications-previous', 'notifications-next']) {
        final rect = tester.getRect(find.byKey(Key(key)));
        expect(rect.left, greaterThanOrEqualTo(0), reason: key);
        expect(rect.right, lessThanOrEqualTo(320), reason: key);
      }
    });

    testWidgets('con texto normal el paginador pone la página arriba y los '
        'botones lado a lado', (tester) async {
      await _pump(
        tester,
        _Repository(
          pages: {
            0: (items: [long], total: 25),
          },
        ),
        size: const Size(320, 2400),
      );
      await tester.ensureVisible(find.byKey(const Key('notifications-next')));
      await tester.pumpAndSettle();

      expectNarrowPager(
        tester,
        label: find.text('Página 1'),
        previous: find.byKey(const Key('notifications-previous')),
        next: find.byKey(const Key('notifications-next')),
      );
    });

    testWidgets('con texto al doble el error de carga entra sin desbordar', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(error: const ApiException('Mensaje largo del servidor.')),
        size: const Size(320, 1200),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(const Key('notifications-error')));
      expect(rect.right, lessThanOrEqualTo(320));
    });
  });
}
