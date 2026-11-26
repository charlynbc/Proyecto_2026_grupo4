import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/novedades/models/admin_announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement.dart';
import 'package:agenda_medica/features/novedades/models/announcement_draft.dart';
import 'package:agenda_medica/features/novedades/models/announcement_page.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/novedades/repositories/fake_announcements_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';
import '../cuenta/account_test_support.dart' show RecordingAccountRepository;
import 'admin_test_support.dart';

const _loadFailure = 'Fallo controlado al actualizar las novedades.';
const _loadingText = 'Cargando novedades…';
const _listError = 'No pudimos cargar las novedades.';

/// Un repositorio con las reglas reales que cuenta los pedidos de cada
/// listado y deja frenar o hacer fallar el próximo.
class _ControlledRepo extends FakeAnnouncementsRepository {
  _ControlledRepo({required List<FakeAnnouncementEntry> seed})
    : super(now: () => kAdminTestNow, seed: seed);

  int adminListCalls = 0;
  int carouselCalls = 0;
  final pages = <int>[];
  bool failNext = false;
  Completer<void>? _gate;

  int get listCalls => pages.length;

  /// Frena el próximo pedido de cualquier listado.
  Completer<void> delayNext() => _gate = Completer<void>();

  void releasePending() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  Future<void> _enter() async {
    final gate = _gate;
    if (gate != null) {
      _gate = null;
      await gate.future;
    }
    if (failNext) {
      failNext = false;
      throw const ApiException(_loadFailure);
    }
  }

  @override
  Future<List<AdminAnnouncement>> adminList() async {
    adminListCalls++;
    await _enter();
    return super.adminList();
  }

  @override
  Future<List<Announcement>> carousel() async {
    carouselCalls++;
    await _enter();
    return super.carousel();
  }

  @override
  Future<AnnouncementPage> list({int page = 0}) async {
    pages.add(page);
    await _enter();
    return super.list(page: page);
  }
}

/// Dos novedades más que una página: la 11 y la 12 quedan en la página 2.
List<FakeAnnouncementEntry> _twelveSeed() => [
  for (var n = 1; n <= 12; n++)
    adminTestEntry(
      n,
      'Boletín ${n.toString().padLeft(2, '0')}',
      published: DateTime.utc(2026, 11, 13).subtract(Duration(days: n)),
      until: DateTime.utc(2026, 12, 1, 3),
    ),
];

class _Harness {
  const _Harness({
    required this.container,
    required this.router,
    required this.repo,
  });

  final ProviderContainer container;
  final GoRouter router;
  final _ControlledRepo repo;
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Future<_Harness> _pump(
  WidgetTester tester, {
  required UserRole role,
  required String location,
  List<FakeAnnouncementEntry>? seed,
  Size size = const Size(1280, 1600),
  double textScale = 1,
  DateTime Function()? clock,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = _ControlledRepo(seed: seed ?? adminTestSeed());
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(() => AdminTestSession(role)),
      announcementClockProvider.overrideWithValue(clock ?? () => kAdminTestNow),
      accountRepositoryProvider.overrideWith(
        (ref) async => RecordingAccountRepository(),
      ),
      announcementsRepositoryProvider.overrideWith((ref) async => repo),
    ],
  );
  final router = container.read(goRouterProvider)..go(location);
  addTearDown(() async {
    repo.releasePending();
    await unmountApp(tester);
    container.dispose();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await _settle(tester);
  return _Harness(container: container, router: router, repo: repo);
}

/// Otra persona publica una novedad mientras esta pantalla no se ve. Queda en
/// la primera posición del carrusel.
Future<void> _someoneElsePublishes(
  _ControlledRepo repo, {
  bool inCarousel = true,
}) async {
  await repo.publish(
    AnnouncementDraft(
      title: 'Atención en feriados',
      visibleUntil: DateTime.utc(2026, 12, 31, 3),
    ),
  );
  if (!inCarousel) return;
  await repo.saveCarousel(const [
    CarouselSlot(position: 1, announcementId: 31),
    CarouselSlot(position: 2, announcementId: 30),
  ]);
}

/// Una de las tres pantallas de la Cartelera y cómo se ve su listado.
class _Screen {
  const _Screen({
    required this.name,
    required this.role,
    required this.path,
    required this.awayPath,
    required this.requests,
  });

  final String name;
  final UserRole role;
  final String path;
  final String awayPath;
  final int Function(_ControlledRepo) requests;
}

void main() {
  final screens = [
    _Screen(
      name: 'Cartelera del administrador',
      role: UserRole.administrador,
      path: '/admin/cartelera',
      awayPath: '/admin/usuarios',
      requests: (repo) => repo.adminListCalls,
    ),
    _Screen(
      name: 'Inicio',
      role: UserRole.socio,
      path: '/socio/inicio',
      awayPath: '/socio/disponibilidad',
      requests: (repo) => repo.carouselCalls,
    ),
    _Screen(
      name: 'Novedades',
      role: UserRole.socio,
      path: '/socio/cartelera',
      awayPath: '/socio/disponibilidad',
      requests: (repo) => repo.listCalls,
    ),
  ];

  for (final screen in screens) {
    group(screen.name, () {
      Future<_Harness> open(
        WidgetTester tester, {
        Size size = const Size(1280, 1600),
        double textScale = 1,
      }) async {
        final harness = await _pump(
          tester,
          role: screen.role,
          location: screen.path,
          size: size,
          textScale: textScale,
        );
        expect(screen.requests(harness.repo), 1);
        expect(find.text('Jornada de vacunación'), findsOneWidget);
        return harness;
      }

      Future<void> leave(WidgetTester tester, _Harness harness) async {
        harness.router.go(screen.awayPath);
        await _settle(tester);
      }

      testWidgets('al volver de otra sección muestra la novedad nueva', (
        tester,
      ) async {
        final harness = await open(tester);

        await leave(tester, harness);
        await _someoneElsePublishes(harness.repo);
        harness.router.go(screen.path);
        await _settle(tester);

        expect(find.text('Atención en feriados'), findsOneWidget);
      });

      testWidgets('al volver hace un pedido y conserva la lista durante la '
          'carga', (tester) async {
        final harness = await open(tester);
        await leave(tester, harness);
        await _someoneElsePublishes(harness.repo);
        final gate = harness.repo.delayNext();

        harness.router.go(screen.path);
        for (var i = 0; i < 12 && screen.requests(harness.repo) < 2; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }

        expect(screen.requests(harness.repo), 2);
        expect(find.text('Jornada de vacunación'), findsOneWidget);
        expect(find.text(_loadingText), findsNothing);

        gate.complete();
        await _settle(tester);
        expect(screen.requests(harness.repo), 2);
        expect(find.text('Atención en feriados'), findsOneWidget);
      });

      testWidgets('al volver del segundo plano hace un pedido y muestra la '
          'novedad nueva', (tester) async {
        final harness = await open(tester);
        await _someoneElsePublishes(harness.repo);

        backgroundAndReturn(tester);
        await _settle(tester);

        expect(screen.requests(harness.repo), 2);
        expect(find.text('Atención en feriados'), findsOneWidget);
      });

      testWidgets('si falla al volver ofrece Reintentar, que muestra la '
          'carga y después la lista', (tester) async {
        final harness = await open(tester);
        await leave(tester, harness);
        await _someoneElsePublishes(harness.repo);
        harness.repo.failNext = true;

        harness.router.go(screen.path);
        await _settle(tester);

        expect(screen.requests(harness.repo), 2);
        expect(find.text(_listError), findsOneWidget);
        expect(find.text(_loadFailure), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);

        final gate = harness.repo.delayNext();
        await tester.tap(find.text('Reintentar'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(screen.requests(harness.repo), 3);
        expect(find.text(_loadingText), findsOneWidget);
        expect(find.text(_listError), findsNothing);

        gate.complete();
        await _settle(tester);
        expect(find.text(_loadingText), findsNothing);
        expect(find.text('Atención en feriados'), findsOneWidget);
      });

      testWidgets('a 320 px con texto al doble el aviso y Reintentar se ven '
          'dentro del ancho', (tester) async {
        await loadRoboto();
        final harness = await open(
          tester,
          size: const Size(320, 1600),
          textScale: 2,
        );
        await leave(tester, harness);
        harness.repo.failNext = true;
        harness.router.go(screen.path);
        await _settle(tester);

        final message = find.text(_listError);
        expect(message, findsOneWidget);
        // El escalado se aplica de verdad: 10 puntos pasan a ser 20.
        expect(MediaQuery.textScalerOf(tester.element(message)).scale(10), 20);
        final retry = find.text('Reintentar');
        expect(retry, findsOneWidget);
        final rect = tester.getRect(retry);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('Novedades: con la página 2 elegida, al volver sigue en la '
      'página 2', (tester) async {
    final harness = await _pump(
      tester,
      role: UserRole.socio,
      location: '/socio/cartelera',
      seed: _twelveSeed(),
    );
    final next = find.text('Siguiente');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await _settle(tester);
    expect(find.text('Página 2'), findsOneWidget);
    expect(find.text('Boletín 11'), findsOneWidget);
    expect(find.text('Boletín 12'), findsOneWidget);
    expect(find.text('Boletín 10'), findsNothing);
    expect(harness.repo.pages, [0, 1]);

    harness.router.go('/socio/disponibilidad');
    await _settle(tester);
    await _someoneElsePublishes(harness.repo, inCarousel: false);
    harness.router.go('/socio/cartelera');
    await _settle(tester);

    // La novedad nueva empuja la 10 a la página 2, que se vuelve a pedir.
    expect(harness.repo.pages, [0, 1, 1]);
    expect(find.text('Página 2'), findsOneWidget);
    expect(find.text('Boletín 10'), findsOneWidget);
    expect(find.text('Boletín 11'), findsOneWidget);
    expect(find.text('Boletín 12'), findsOneWidget);
    expect(find.text('Atención en feriados'), findsNothing);
  });

  // Las URL de las portadas vencen a los 55 minutos de cargada la lista. El
  // reloj de las pruebas se mueve a mano: `at(54)` son 54 minutos después de
  // la carga inicial.
  for (final screen in screens.skip(1)) {
    group('${screen.name}: vencimiento de las URL a los 55 minutos', () {
      var now = kAdminTestNow;
      void at(int minutes) =>
          now = kAdminTestNow.add(Duration(minutes: minutes));

      Future<_Harness> open(WidgetTester tester) async {
        now = kAdminTestNow;
        final harness = await _pump(
          tester,
          role: screen.role,
          location: screen.path,
          clock: () => now,
        );
        expect(screen.requests(harness.repo), 1);
        return harness;
      }

      Future<void> resize(WidgetTester tester) async {
        // Un cambio de tamaño reconstruye la pantalla sin traer datos nuevos.
        tester.view.physicalSize = const Size(1100, 1600);
        await _settle(tester);
      }

      testWidgets('a los 54 minutos un rebuild no pide nada y a los 56 minutos '
          'se pide una sola vez', (tester) async {
        final harness = await open(tester);

        at(54);
        await resize(tester);
        expect(screen.requests(harness.repo), 1);

        at(56);
        backgroundAndReturn(tester);
        await _settle(tester);
        expect(screen.requests(harness.repo), 2);
      });

      testWidgets('un refresco al volver reinicia la cuenta de los 55 '
          'minutos', (tester) async {
        final harness = await open(tester);

        at(40);
        harness.router.go(screen.awayPath);
        await _settle(tester);
        harness.router.go(screen.path);
        await _settle(tester);
        expect(screen.requests(harness.repo), 2);

        // Pasaron 94 minutos de la primera carga y 54 de la última.
        at(94);
        backgroundAndReturn(tester);
        await _settle(tester);
        expect(screen.requests(harness.repo), 3);
      });

      testWidgets('un rebuild sin dato nuevo no reinicia la cuenta', (
        tester,
      ) async {
        final harness = await open(tester);

        at(30);
        await resize(tester);
        expect(screen.requests(harness.repo), 1);

        // Siguen contando desde la carga: 56 minutos después hay un pedido.
        at(56);
        backgroundAndReturn(tester);
        await _settle(tester);
        expect(screen.requests(harness.repo), 2);
      });

      testWidgets('si coinciden el refresco al volver y el de los 55 minutos '
          'hace un solo pedido', (tester) async {
        final harness = await open(tester);
        harness.router.go(screen.awayPath);
        await _settle(tester);

        at(56);
        harness.router.go(screen.path);
        await _settle(tester);

        expect(screen.requests(harness.repo), 2);
      });
    });
  }

  testWidgets('Novedades: al cambiar a la página 2 la cuenta de los 55 '
      'minutos es la de la página 2', (tester) async {
    var now = kAdminTestNow;
    final harness = await _pump(
      tester,
      role: UserRole.socio,
      location: '/socio/cartelera',
      seed: _twelveSeed(),
      clock: () => now,
    );

    now = kAdminTestNow.add(const Duration(minutes: 50));
    final next = find.text('Siguiente');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await _settle(tester);
    expect(harness.repo.pages, [0, 1]);

    // Pasaron 100 minutos de la primera página y 50 de la segunda.
    now = kAdminTestNow.add(const Duration(minutes: 100));
    backgroundAndReturn(tester);
    await _settle(tester);

    expect(harness.repo.pages, [0, 1, 1]);
  });

  // Mientras la lista se refresca se sigue viendo la anterior, pero no se puede
  // tocar una novedad que quizás ya no existe o cambió.
  group('Cartelera del administrador: acciones durante el refresco', () {
    const path = '/admin/cartelera';
    const away = '/admin/usuarios';

    Future<_Harness> open(
      WidgetTester tester, {
      Size size = const Size(1280, 1600),
      double textScale = 1,
    }) async {
      final harness = await _pump(
        tester,
        role: UserRole.administrador,
        location: path,
        size: size,
        textScale: textScale,
      );
      expect(harness.repo.adminListCalls, 1);
      return harness;
    }

    Finder action(String kind, int id) =>
        find.byKey(ValueKey('admin-$kind-$id'));

    Finder carousel() => find.ancestor(
      of: find.text('Elegir carrusel'),
      matching: find.bySubtype<ButtonStyleButton>(),
    );

    bool enabled(WidgetTester tester, Finder finder) =>
        tester.widget<ButtonStyleButton>(finder).onPressed != null;

    /// Las acciones de las tres novedades y el botón del carrusel.
    void expectActions(WidgetTester tester, {required bool enabledNow}) {
      for (final id in [30, 20, 10]) {
        for (final kind in ['edit', 'validity', 'delete']) {
          expect(
            enabled(tester, action(kind, id)),
            enabledNow,
            reason: '$kind $id',
          );
        }
      }
      expect(enabled(tester, carousel()), enabledNow, reason: 'carrusel');
    }

    /// Frena el próximo pedido de la lista y lo dispara con "Actualizar".
    Future<Completer<void>> startRefresh(
      WidgetTester tester,
      _Harness harness,
    ) async {
      final gate = harness.repo.delayNext();
      final refresh = find.text('Actualizar novedades');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pump();
      await tester.pump();
      expect(harness.repo.adminListCalls, 2);
      return gate;
    }

    testWidgets('al eliminar, la fila eliminada sigue visible pero sin '
        'Eliminar hasta que llega la lista nueva', (tester) async {
      final harness = await open(tester);
      final delete = action('delete', 20);
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      final gate = harness.repo.delayNext();

      await tester.tap(find.text('Eliminar novedad'));
      await tester.pump();
      await tester.pump();

      expect(harness.repo.adminListCalls, 2);
      expect(
        find.byKey(const ValueKey('admin-announcement-20')),
        findsOneWidget,
      );
      expect(enabled(tester, action('delete', 20)), isFalse);
      expect(enabled(tester, action('delete', 30)), isFalse);

      gate.complete();
      await _settle(tester);
      expect(find.byKey(const ValueKey('admin-announcement-20')), findsNothing);
      expect(enabled(tester, action('delete', 30)), isTrue);
    });

    testWidgets('editar, vigencia, eliminar y carrusel quedan deshabilitados '
        'durante un refresco y se habilitan después', (tester) async {
      final harness = await open(tester);
      expectActions(tester, enabledNow: true);

      final gate = await startRefresh(tester, harness);
      expect(find.text('Jornada de vacunación'), findsOneWidget);
      expectActions(tester, enabledNow: false);

      gate.complete();
      await _settle(tester);
      expectActions(tester, enabledNow: true);
    });

    testWidgets('al volver de otra sección con el refresco en curso las '
        'acciones esperan a la lista nueva', (tester) async {
      final harness = await open(tester);
      harness.router.go(away);
      await _settle(tester);
      final gate = harness.repo.delayNext();

      harness.router.go(path);
      for (var i = 0; i < 12 && harness.repo.adminListCalls < 2; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(harness.repo.adminListCalls, 2);
      expect(find.text('Jornada de vacunación'), findsOneWidget);
      expectActions(tester, enabledNow: false);

      gate.complete();
      await _settle(tester);
      expectActions(tester, enabledNow: true);
    });

    testWidgets('el botón deshabilitado conserva su etiqueta para el lector '
        'de pantalla', (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = await open(tester);

      await startRefresh(tester, harness);

      expect(
        tester.getSemantics(action('delete', 30)),
        isSemantics(label: 'Eliminar', hasEnabledState: true, isEnabled: false),
      );
      expect(
        tester.getSemantics(action('edit', 30)),
        isSemantics(label: 'Editar', hasEnabledState: true, isEnabled: false),
      );
      semantics.dispose();
    });

    testWidgets('a 320 px con texto al doble no desborda durante el '
        'refresco', (tester) async {
      await loadRoboto();
      final harness = await open(
        tester,
        size: const Size(320, 1600),
        textScale: 2,
      );

      await startRefresh(tester, harness);

      expectActions(tester, enabledNow: false);
      expect(tester.takeException(), isNull);
    });
  });
}
