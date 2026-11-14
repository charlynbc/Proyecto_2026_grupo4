import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/adaptive_nav_bar.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/home/widgets/announcements_carousel.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_detail.dart';
import 'package:agenda_medica/features/novedades/models/announcement_page.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import '../cuenta/account_test_support.dart' show RecordingAccountRepository;

class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    role: UserRole.socio,
    accessToken: 'sesion-de-prueba',
  );
}

class _News extends FakeAnnouncementsRepository {
  @override
  Future<AnnouncementPage> list({int page = 0}) async => AnnouncementPage(
    items: items.take(10).toList(),
    page: page,
    total: items.length,
  );

  final List<int> details = [];

  @override
  Future<AnnouncementDetail> detail(int id) async {
    details.add(id);
    return AnnouncementDetail(
      id: id,
      title: 'Detalle $id',
      text: '**Texto** de la novedad.',
      publishedAt: DateTime.utc(2026, 11, 1),
    );
  }

  List<Announcement> items = [];
  Object? error;
  Completer<List<Announcement>>? pending;
  int calls = 0;

  @override
  Future<List<Announcement>> latest() async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? items : pending!.future;
  }
}

Announcement news(int id, {String? title, String? summary, String? cover}) =>
    Announcement(
      id: id,
      title: title ?? 'Novedad $id',
      summary: summary,
      coverUrl: cover,
      publishedAt: DateTime.utc(2026, 11, id),
    );

Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  _News news, {
  double width = 1280,
  double scale = 1,
  RecordingAccountRepository? account,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_Session.new),
      announcementsRepositoryProvider.overrideWith((ref) async => news),
      accountRepositoryProvider.overrideWith(
        (ref) async => account ?? RecordingAccountRepository(),
      ),
    ],
  );
  addTearDown(() async {
    await unmountApp(tester);
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        routerConfig: container.read(goRouterProvider),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  if (news.pending == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return container;
}

void main() {
  setUpAll(loadRoboto);

  testWidgets(
    'entra al Inicio, saluda y muestra cuatro cuadrados en una fila',
    (tester) async {
      final container = await _pumpHome(tester, _News()..items = [news(1)]);
      expect(locationOf(container), '/socio/inicio');
      expect(find.text('Bienvenido/a, Lucía'), findsOneWidget);
      expect(find.byKey(const Key('home-logo')), findsOneWidget);
      final logo = find.byKey(const Key('home-logo'));
      expect(tester.getSize(logo), const Size(80, 80));
      expect(
        tester.getTopLeft(find.text('Médica Oriental')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(logo).dy),
      );
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(AdaptiveNavBar), findsNothing);
      expect(find.text('Médica Oriental'), findsOneWidget);
      expect(find.text('Lucía Fernández'), findsOneWidget);
      expect(find.text('Socio'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home-welcome-banner')),
          matching: find.byKey(const Key('home-greeting')),
        ),
        findsOneWidget,
      );
      final tiles = [
        for (final slug in [
          'disponibilidad',
          'consultas',
          'historia',
          'cartelera',
        ])
          find.byKey(Key('home-shortcut-$slug')),
      ];
      final top = tester.getTopLeft(tiles.first).dy;
      for (final tile in tiles) {
        expect(tester.getTopLeft(tile).dy, top);
        final size = tester.getSize(tile);
        expect(size.width, size.height);
        expect(size, tester.getSize(tiles.first));
      }
      expect(find.byTooltip('Novedad siguiente'), findsNothing);
      expect(find.byTooltip('Mi cuenta'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('los cuatro accesos conservan sus destinos existentes', (
    tester,
  ) async {
    final container = await _pumpHome(tester, _News());
    for (final (slug, path) in [
      ('disponibilidad', '/socio/disponibilidad'),
      ('consultas', '/socio/consultas'),
      ('historia', '/socio/historia'),
      ('cartelera', '/socio/cartelera'),
    ]) {
      await goTo(tester, container, '/socio/inicio');
      expect(find.byType(NavigationRail), findsNothing);
      final shortcut = find.byKey(Key('home-shortcut-$slug'));
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(locationOf(container), path);
      expect(find.byType(NavigationRail), findsOneWidget);
    }
    expect(find.text('Próximamente'), findsNothing);
    expect(find.text('Novedades'), findsOneWidget);
  });

  testWidgets(
    'tarjetas abren su detalle y conservan Inicio; Ver todas abre el listado',
    (tester) async {
      final repo = _News()..items = [news(1), news(2), news(3)];
      final container = await _pumpHome(tester, repo);
      await tester.tap(find.byKey(const Key('announcement-1')));
      await tester.pumpAndSettle();
      expect(locationOf(container), '/socio/cartelera/1');
      expect(find.text('Detalle 1'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      await tester.tap(find.byTooltip('Volver al Inicio'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsNothing);
      await tester.tap(find.byTooltip('Novedad siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver novedad').hitTestable());
      await tester.pumpAndSettle();
      expect(locationOf(container), '/socio/cartelera/2');
      expect(find.text('Detalle 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver al Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Novedad 2').hitTestable(), findsOneWidget);
      expect(repo.calls, 1);
      expect(repo.details, [1, 2]);
      await tester.tap(find.text('Ver todas las novedades'));
      await tester.pumpAndSettle();
      expect(locationOf(container), '/socio/cartelera');
    },
  );

  testWidgets(
    'flechas e indicadores recorren novedades distintas manualmente',
    (tester) async {
      await _pumpHome(tester, _News()..items = [news(1), news(2), news(3)]);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Novedad anterior',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Novedad siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Novedad 2').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Novedad 3 de 3'));
      await tester.pumpAndSettle();
      expect(find.text('Novedad 3').hitTestable(), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip == 'Novedad siguiente',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Novedad anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Novedad 2').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('carga y ausencia de publicaciones mantienen los accesos', (
    tester,
  ) async {
    final repo = _News()..pending = Completer<List<Announcement>>();
    await _pumpHome(tester, repo);
    expect(find.text('Cargando novedades…'), findsOneWidget);
    expect(
      find.byKey(const Key('home-shortcut-disponibilidad')),
      findsOneWidget,
    );
    repo.pending!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay novedades publicadas.'), findsOneWidget);
    expect(find.byType(AnnouncementsCarousel), findsNothing);
  });

  testWidgets('un error permite reintentar sin bloquear los accesos', (
    tester,
  ) async {
    final repo = _News()..error = const ApiException('Error de prueba');
    await _pumpHome(tester, repo);
    expect(find.text('No pudimos cargar las novedades.'), findsOneWidget);
    expect(find.byKey(const Key('home-shortcut-historia')), findsOneWidget);
    repo.error = null;
    repo.items = [news(1)];
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Novedad 1'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('falla de la cuenta conserva el saludo y las novedades', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      _News()..items = [news(1)],
      account: RecordingAccountRepository(error: const ApiException()),
    );
    expect(find.text('Bienvenido/a'), findsOneWidget);
    expect(find.text('Novedad 1'), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 600.0, 900.0, 1440.0]) {
    testWidgets(
      'a $width px admite texto largo, portada fallida y resumen ausente',
      (tester) async {
        await _pumpHome(
          tester,
          _News()
            ..items = [
              news(
                1,
                title: List.filled(16, 'Título extenso').join(' '),
                cover: 'https://example.invalid/no-existe.png',
              ),
            ],
          width: width,
        );
        expect(
          find.byKey(const Key('announcement-placeholder-1')),
          findsOneWidget,
        );
        if (width < 600) {
          expect(find.text('Socio'), findsOneWidget);
          expect(find.byType(AdaptiveNavBar), findsNothing);
          final first = find.byKey(const Key('home-shortcut-disponibilidad'));
          final second = find.byKey(const Key('home-shortcut-consultas'));
          final third = find.byKey(const Key('home-shortcut-historia'));
          expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
          expect(
            tester.getTopLeft(third).dy,
            greaterThan(tester.getTopLeft(first).dy),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('320 px y texto al doble no desbordan', (tester) async {
    await _pumpHome(
      tester,
      _News()
        ..items = [
          news(
            1,
            title: List.filled(10, 'Título extenso').join(' '),
            summary: List.filled(10, 'Resumen extenso').join(' '),
          ),
        ],
      width: 320,
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  // Con un ancho casi nulo (por ejemplo, al abrir las herramientas del
  // navegador) el tamaño de los atajos no puede salir negativo. Los desbordes
  // por debajo de ~56 px son otro tema y no se miran acá.
  for (final width in [55.0, 40.0, 16.0, 8.0, 1.0, 0.0]) {
    testWidgets('a $width px los atajos no tienen un tamaño negativo', (
      tester,
    ) async {
      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = errors.add;

      try {
        await _pumpHome(tester, _News()..items = [news(1)], width: width);
      } on AssertionError catch (e) {
        // Con el layout roto la pantalla nunca se asienta; no es lo que se mira.
        if (!e.toString().contains('pumpAndSettle timed out')) rethrow;
      } finally {
        FlutterError.onError = original;
      }

      final negative = errors
          .where((e) => e.exceptionAsString().contains('negative minimum'))
          .toList();
      expect(negative, isEmpty, reason: negative.join(' | '));
    });
  }
}
