import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_correction_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_correction_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';

const _loadFailure = 'Fallo controlado al actualizar los consultorios.';
const _visibleListError =
    'No pudimos cargar los consultorios. Intentá de nuevo.';
const _otherSection = kSpecialtiesPath;

class _AdminSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'consultorios-estado-actual-prueba',
    role: UserRole.administrador,
  );
}

class _ControlledClinicSearch extends FakeClinicSearchRepository {
  _ControlledClinicSearch(super.db, {super.latency = Duration.zero});

  final queries = <ClinicFilters>[];
  bool failNext = false;
  Completer<void>? _nextGate;
  Completer<void>? _activeGate;

  int get calls => queries.length;

  /// Frena el próximo pedido de la lista, sea cual sea.
  Completer<void> delayNext() {
    final gate = Completer<void>();
    _nextGate = gate;
    return gate;
  }

  void releasePending() {
    final gates = [_nextGate, _activeGate];
    _nextGate = null;
    _activeGate = null;
    for (final gate in gates) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<List<Clinic>> search(ClinicFilters filters) async {
    queries.add(filters);
    final gate = _nextGate;
    _nextGate = null;
    if (gate != null) {
      _activeGate = gate;
      await gate.future;
      _activeGate = null;
    }
    if (failNext) {
      failNext = false;
      throw const ApiException(_loadFailure);
    }
    return super.search(filters);
  }
}

class _Harness {
  const _Harness({
    required this.container,
    required this.router,
    required this.database,
    required this.search,
  });

  final ProviderContainer container;
  final GoRouter router;
  final FakeAdminDatabase database;
  final _ControlledClinicSearch search;
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

/// Monta el router real con su shell. Con [settle] en `false` solo avanza un
/// cuadro: el test del bucle mide el tiempo por su cuenta.
Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(1600, 1400),
  double textScale = 1,
  bool failFirst = false,
  bool settle = true,
  Duration searchLatency = Duration.zero,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final database = FakeAdminDatabase();
  database.clinics
    ..clear()
    ..addAll(const [
      Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2, ala norte'),
      Clinic(id: 6, name: 'Consultorio 6', location: 'Piso 2, ala sur'),
      Clinic(id: 12, name: 'Consultorio 12', location: 'Planta baja'),
    ]);
  final search = _ControlledClinicSearch(database, latency: searchLatency)
    ..failNext = failFirst;
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_AdminSession.new),
      fakeAdminDatabaseProvider.overrideWithValue(database),
      clinicSearchRepositoryProvider.overrideWith((ref) async => search),
      clinicRepositoryProvider.overrideWith(
        (ref) async => FakeClinicRepository(database, latency: Duration.zero),
      ),
      clinicCorrectionRepositoryProvider.overrideWith(
        (ref) async =>
            FakeClinicCorrectionRepository(database, latency: Duration.zero),
      ),
      latestAnnouncementsProvider.overrideWith((ref) async => []),
    ],
  );
  final router = container.read(goRouterProvider)..go(kClinicsPath);
  addTearDown(() async {
    search.releasePending();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: appTheme,
        locale: const Locale('es', 'UY'),
        supportedLocales: const [Locale('es', 'UY')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  if (settle) {
    await _settle(tester);
    expect(find.byType(ClinicsScreen), findsOneWidget);
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }

  return _Harness(
    container: container,
    router: router,
    database: database,
    search: search,
  );
}

/// Otro administrador da de alta un consultorio mientras esta pantalla no
/// mira. Por nombre queda después del 12.
void _addOtherAdminClinic(_Harness harness) {
  harness.database.clinics.add(
    const Clinic(id: 40, name: 'Consultorio 20', location: 'Piso 9'),
  );
}

Future<void> _leave(WidgetTester tester, _Harness harness) async {
  harness.router.go(_otherSection);
  await _settle(tester);
}

Future<void> _pumpUntilCalls(
  WidgetTester tester,
  _ControlledClinicSearch search,
  int expected,
) async {
  for (var attempt = 0; attempt < 12 && search.calls < expected; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await _settle(tester);
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await _tap(tester, key);
  final menuItem = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.role == SemanticsRole.menuItem,
    ),
  );
  final option = find
      .descendant(of: menuItem, matching: find.byType(InkWell))
      .hitTestable();
  await tester.tap(option);
  await tester.pump();
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

/// Los nombres de las tarjetas, de arriba hacia abajo.
List<String> _names(WidgetTester tester) {
  final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
  return [for (final tile in tiles) (tile.title! as Text).data!];
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('con el shell real la pantalla no entra en un bucle de pedidos', (
    tester,
  ) async {
    // Cada pedido tarda 50 ms de reloj falso: si algo vuelve a pedir en
    // bucle, el tiempo avanza y el test cuenta en vez de colgarse.
    final harness = await _pump(
      tester,
      settle: false,
      searchLatency: const Duration(milliseconds: 50),
    );

    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (harness.search.calls > 500) break;
    }

    // 10 segundos de reloj falso y un solo pedido, el de la carga inicial.
    expect(harness.search.calls, 1);
    expect(find.byType(ClinicsScreen), findsOneWidget);
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);
  });

  testWidgets('al volver desde otra sección muestra el consultorio nuevo', (
    tester,
  ) async {
    final harness = await _pump(tester);
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);

    await _leave(tester, harness);
    _addOtherAdminClinic(harness);
    harness.router.go(kClinicsPath);
    await _settle(tester);

    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
      'Consultorio 20',
    ]);
  });

  testWidgets('al volver hace un pedido y conserva la lista durante la carga', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _leave(tester, harness);
    _addOtherAdminClinic(harness);
    final gate = harness.search.delayNext();

    harness.router.go(kClinicsPath);
    await _pumpUntilCalls(tester, harness.search, 2);

    // Cuenta la carga inicial y el único pedido al volver.
    expect(harness.search.calls, 2);
    // La lista anterior sigue visible y sin indicador de carga.
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(harness.search.calls, 2);
    expect(_names(tester).last, 'Consultorio 20');
  });

  testWidgets('al volver del segundo plano pide una vez y muestra lo nuevo', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _addOtherAdminClinic(harness);

    backgroundAndReturn(tester);
    await _settle(tester);

    expect(harness.search.calls, 2);
    expect(_names(tester).last, 'Consultorio 20');
  });

  testWidgets('si falla al volver ofrece Reintentar y este muestra la carga', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _leave(tester, harness);
    _addOtherAdminClinic(harness);
    harness.search.failNext = true;

    harness.router.go(kClinicsPath);
    await _settle(tester);

    // Al volver se hizo un segundo pedido y su falla se muestra enseguida.
    expect(harness.search.calls, 2);
    expect(find.text(_visibleListError), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    expect(retry, findsOneWidget);
    final gate = harness.search.delayNext();

    await tester.tap(retry);
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.search.calls, 3);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_visibleListError), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_names(tester).last, 'Consultorio 20');
  });

  testWidgets('si falla la carga inicial el aviso aparece enseguida y con un '
      'solo pedido', (tester) async {
    final harness = await _pump(tester, failFirst: true);

    // Sin reintento automático: un pedido, y el aviso ya está a la vista.
    expect(harness.search.calls, 1);
    expect(find.text(_visibleListError), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    expect(retry, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(retry);
    await _settle(tester);
    expect(harness.search.calls, 2);
    expect(find.text(_visibleListError), findsNothing);
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);
  });

  testWidgets('al volver conserva los filtros y el orden aplicados', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _enter(tester, 'clinic-filter-location', 'piso');
    await _tap(tester, 'clinic-filter-search');
    await _select(tester, 'clinic-filter-order', 'Ubicación');
    expect(harness.search.calls, 3);
    expect(harness.search.queries.last.toQueryParameters(), {
      'ubicacion': 'piso',
      'orden': 'ubicacion',
    });
    expect(_names(tester), ['Consultorio 5', 'Consultorio 6']);

    await _leave(tester, harness);
    _addOtherAdminClinic(harness);
    harness.router.go(kClinicsPath);
    await _settle(tester);

    expect(harness.search.calls, 4);
    expect(harness.search.queries.last.toQueryParameters(), {
      'ubicacion': 'piso',
      'orden': 'ubicacion',
    });
    // El consultorio 20 está en "Piso 9": entra en el filtro "piso".
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 20',
    ]);
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('clinic-filter-location')),
          )
          .controller!
          .text,
      'piso',
    );
  });

  testWidgets(
    'al cambiar un filtro muestra carga en vez de la lista anterior',
    (tester) async {
      final harness = await _pump(tester);
      await _enter(tester, 'clinic-filter-name', '12');
      final gate = harness.search.delayNext();
      final search = find.byKey(const Key('clinic-filter-search'));
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pump(const Duration(milliseconds: 100));

      expect(harness.search.calls, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      gate.complete();
      await _settle(tester);
      expect(_names(tester), ['Consultorio 12']);
    },
  );

  testWidgets('Buscar con los mismos parámetros vuelve a pedir con carga', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final gate = harness.search.delayNext();
    final search = find.byKey(const Key('clinic-filter-search'));
    await tester.ensureVisible(search);
    await tester.tap(search);
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.search.calls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);
  });

  testWidgets('Limpiar vuelve a pedir con carga aunque no haya filtros', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final gate = harness.search.delayNext();
    final clear = find.byKey(const Key('clinic-filter-clear'));
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.search.calls, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(harness.search.calls, 2);
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);
  });

  testWidgets('cambiar el orden pide de nuevo con carga y el sentido no', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final gate = harness.search.delayNext();

    await _tap(tester, 'clinic-filter-order');
    final menuItem = find.ancestor(
      of: find.text('Ubicación'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.role == SemanticsRole.menuItem,
      ),
    );
    await tester.tap(
      find
          .descendant(of: menuItem, matching: find.byType(InkWell))
          .hitTestable(),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Un pedido nuevo con el orden, y la lista anterior oculta mientras llega.
    expect(harness.search.calls, 2);
    expect(harness.search.queries.last.toQueryParameters(), {
      'orden': 'ubicacion',
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);

    // Alternar el sentido invierte lo cargado: sin pedido y sin carga.
    await _tap(tester, 'clinic-filter-direction');
    expect(harness.search.calls, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_names(tester), [
      'Consultorio 12',
      'Consultorio 6',
      'Consultorio 5',
    ]);
  });

  testWidgets('con Corregir apilado, Volver sin guardar no refresca la lista', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _addOtherAdminClinic(harness);

    await tester.tap(find.byKey(const Key('clinic-edit-5')));
    await _settle(tester);
    expect(find.text('Corregir consultorio'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await _settle(tester);

    // Limitación conocida: la pantalla de Corregir mantiene vivo el
    // provider, así que volver a la lista no cuenta como "volver a verse".
    expect(find.byType(ClinicsScreen), findsOneWidget);
    expect(harness.search.calls, 1);
    expect(_names(tester), [
      'Consultorio 5',
      'Consultorio 6',
      'Consultorio 12',
    ]);
  });

  testWidgets('con Corregir apilado, Guardar sí refresca la lista', (
    tester,
  ) async {
    final harness = await _pump(tester);

    await tester.tap(find.byKey(const Key('clinic-edit-5')));
    await _settle(tester);
    final fields = find.descendant(
      of: find.byType(Form),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(1), 'Piso 7');
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-clinic-save')));
    await _settle(tester);

    expect(find.byType(ClinicsScreen), findsOneWidget);
    expect(harness.search.calls, 2);
    expect(find.text('Piso 7'), findsOneWidget);
  });

  testWidgets('a 320 px con texto al doble el aviso y Reintentar se ven '
      'dentro del ancho', (tester) async {
    final harness = await _pump(
      tester,
      size: const Size(320, 800),
      textScale: 2,
    );
    await _leave(tester, harness);
    harness.search.failNext = true;
    harness.router.go(kClinicsPath);
    await _settle(tester);

    final message = find.text(_visibleListError);
    expect(message, findsOneWidget);
    // El escalado se aplica de verdad: 10 puntos pasan a ser 20.
    expect(MediaQuery.textScalerOf(tester.element(message)).scale(10), 20);
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    expect(retry, findsOneWidget);
    final rect = tester.getRect(retry);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });
}
