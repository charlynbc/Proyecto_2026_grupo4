import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/providers/shift_filters_controller.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/shift_listing_data.dart';

const _loadFailure = 'Fallo controlado al actualizar los turnos.';
const _visibleListError = 'No pudimos cargar los turnos. Intentá de nuevo.';

class _StaffSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'turnos-estado-actual-prueba',
    role: UserRole.funcionario,
  );
}

class _ControlledShiftRepository extends FakeShiftRepository {
  _ControlledShiftRepository(super.db) : super(latency: Duration.zero);

  final filters = <ShiftFilters>[];
  bool failNextList = false;
  Completer<void>? _secondListGate;
  Completer<void>? _weekdayListGate;
  Completer<void>? _activeGate;
  Completer<void>? _nextGate;

  int get listCalls => filters.length;

  /// Frena el próximo pedido de la lista, sea cual sea.
  Completer<void> delayNextList() {
    final gate = Completer<void>();
    _nextGate = gate;
    return gate;
  }

  Completer<void> delaySecondList() {
    final gate = Completer<void>();
    _secondListGate = gate;
    return gate;
  }

  Completer<void> delayWeekdayList() {
    final gate = Completer<void>();
    _weekdayListGate = gate;
    return gate;
  }

  void releasePending() {
    final gates = [_secondListGate, _weekdayListGate, _nextGate, _activeGate];
    _nextGate = null;
    _secondListGate = null;
    _weekdayListGate = null;
    _activeGate = null;
    for (final gate in gates) {
      if (gate != null && !gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<ShiftPage> listShifts(ShiftFilters query) async {
    filters.add(query);
    final Completer<void>? gate;
    if (_nextGate != null) {
      gate = _nextGate;
      _nextGate = null;
    } else if (query.weekday == 2) {
      gate = _weekdayListGate;
      _weekdayListGate = null;
    } else if (filters.length == 2) {
      gate = _secondListGate;
      _secondListGate = null;
    } else {
      gate = null;
    }
    if (gate != null) {
      _activeGate = gate;
      await gate.future;
      _activeGate = null;
    }
    if (failNextList) {
      failNextList = false;
      throw const ApiException(_loadFailure);
    }
    return super.listShifts(query);
  }
}

class _Harness {
  const _Harness({
    required this.container,
    required this.router,
    required this.database,
    required this.repository,
  });

  final ProviderContainer container;
  final GoRouter router;
  final FakeShiftDatabase database;
  final _ControlledShiftRepository repository;
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(1600, 1400),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final admin = FakeAdminDatabase();
  final database = buildListingDb(admin);
  final repository = _ControlledShiftRepository(database);
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_StaffSession.new),
      shiftRepositoryProvider.overrideWith((ref) async => repository),
      latestAnnouncementsProvider.overrideWith((ref) async => []),
      specialtiesProvider.overrideWith(
        (ref) async => const [
          Specialty(id: 1, name: 'Medicina General', requiresReferral: false),
          Specialty(id: 2, name: 'Cardiología', requiresReferral: true),
          Specialty(id: 3, name: 'Dermatología', requiresReferral: true),
        ],
      ),
    ],
  );
  final router = container.read(goRouterProvider)..go(kShiftsPath);
  addTearDown(() async {
    repository.releasePending();
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
  await _settle(tester);
  expect(find.byType(ShiftsScreen), findsOneWidget);
  expect(find.text('Página 1 de 2 · 32 turnos'), findsOneWidget);

  return _Harness(
    container: container,
    router: router,
    database: database,
    repository: repository,
  );
}

List<List<String>> _rows(WidgetTester tester) => [
  for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
    [
      for (final cell in row.cells)
        if (cell.child is Text) (cell.child as Text).data!,
    ],
];

List<String> _rowForDate(WidgetTester tester, String date) =>
    _rows(tester).singleWhere((row) => row[0] == date);

void _suspendDate(_Harness harness, DateTime date) {
  final id = harness.database.shifts
      .singleWhere((shift) => shift.date == date)
      .id;
  harness.database.suspendShift(id);
}

Future<void> _leaveAndReturn(WidgetTester tester, _Harness harness) async {
  harness.router.go('/funcionario/llegada');
  await _settle(tester);
  harness.router.go(kShiftsPath);
  await _settle(tester);
}

Future<void> _choose(WidgetTester tester, Key key, String option) async {
  final dropdown = find.byKey(key);
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilListCalls(
  WidgetTester tester,
  _ControlledShiftRepository repository,
  int expected,
) async {
  for (
    var attempt = 0;
    attempt < 12 && repository.listCalls < expected;
    attempt++
  ) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _applySearch(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Buscar');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('al volver desde otra sección muestra el estado nuevo', (
    tester,
  ) async {
    final harness = await _pump(tester);
    expect(_rowForDate(tester, '20/10/2026')[7], 'Activa');

    harness.router.go('/funcionario/llegada');
    await _settle(tester);
    _suspendDate(harness, DateTime.utc(2026, 10, 20));
    harness.router.go(kShiftsPath);
    await _settle(tester);

    expect(_rowForDate(tester, '20/10/2026')[7], 'Suspendida');
  });

  testWidgets('al volver del segundo plano muestra el estado nuevo', (
    tester,
  ) async {
    final harness = await _pump(tester);
    expect(_rowForDate(tester, '20/10/2026')[7], 'Activa');
    _suspendDate(harness, DateTime.utc(2026, 10, 20));

    backgroundAndReturn(tester);
    await _settle(tester);

    expect(_rowForDate(tester, '20/10/2026')[7], 'Suspendida');
  });

  testWidgets(
    'al volver conserva filtros, orden y página y muestra datos nuevos',
    (tester) async {
      final harness = await _pump(tester);

      await _choose(tester, const Key('filter-weekday'), 'Lunes');
      await _applySearch(tester);
      await _choose(tester, const Key('filter-order'), 'Médico');
      final direction = find.text('Ascendente');
      await tester.ensureVisible(direction);
      await tester.tap(direction);
      await tester.pumpAndSettle();
      final next = find.text('Siguiente');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await _settle(tester);

      expect(find.text('Página 2 de 2 · 24 turnos'), findsOneWidget);
      expect(
        harness.container.read(shiftFiltersControllerProvider),
        const ShiftFilters(
          weekday: 1,
          order: ShiftOrder.doctor,
          ascending: false,
          page: 1,
        ),
      );

      _suspendDate(harness, DateTime.utc(2027, 3, 22));
      await _leaveAndReturn(tester, harness);

      expect(find.text('Página 2 de 2 · 24 turnos'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<int?>>(
              find.byKey(const Key('filter-weekday')),
            )
            .initialValue,
        1,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<ShiftOrder>>(
              find.byKey(const Key('filter-order')),
            )
            .initialValue,
        ShiftOrder.doctor,
      );
      expect(find.text('Descendente'), findsOneWidget);
      expect(_rowForDate(tester, '22/03/2027')[7], 'Suspendida');
    },
  );

  testWidgets('al volver hace un pedido y conserva la lista durante la carga', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _suspendDate(harness, DateTime.utc(2026, 10, 20));
    harness.router.go('/funcionario/llegada');
    await _settle(tester);
    final gate = harness.repository.delaySecondList();

    harness.router.go(kShiftsPath);
    await _pumpUntilListCalls(tester, harness.repository, 2);

    // Cuenta la carga inicial y el único pedido al volver.
    expect(harness.repository.listCalls, 2);
    // La lista anterior sigue visible mientras espera el segundo pedido.
    expect(_rowForDate(tester, '20/10/2026')[7], 'Activa');
    // No se muestra un indicador durante la recarga.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await _settle(tester);
    // Al terminar el pedido se ve el estado actualizado.
    expect(_rowForDate(tester, '20/10/2026')[7], 'Suspendida');
  });

  testWidgets('si falla al volver ofrece reintentar y carga los datos', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _suspendDate(harness, DateTime.utc(2026, 10, 20));
    harness.router.go('/funcionario/llegada');
    await _settle(tester);
    harness.repository.failNextList = true;

    harness.router.go(kShiftsPath);
    await _settle(tester);

    // Al volver debería haberse hecho un segundo pedido.
    expect(harness.repository.listCalls, 2);
    expect(find.text(_visibleListError), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await _settle(tester);
    expect(_rowForDate(tester, '20/10/2026')[7], 'Suspendida');
  });

  testWidgets(
    'al cambiar un filtro muestra carga en vez de la lista anterior',
    (tester) async {
      final harness = await _pump(tester);
      final gate = harness.repository.delayWeekdayList();

      await _choose(tester, const Key('filter-weekday'), 'Martes');
      // Historia clínica y Atenciones muestran la carga al cambiar el filtro.
      final search = find.widgetWithText(FilledButton, 'Buscar');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pump(const Duration(milliseconds: 100));

      // Son 3 pedidos y no 2: la carga inicial, un segundo pedido con los
      // mismos filtros y el de martes. El segundo no viene del refresco al
      // volver (refetchWhenVisibleAgain) sino de _ReloadShiftsWhenShown
      // (shifts_screen.dart:68-102), que ya existía en la base: abrir un
      // desplegable de filtros apila una ruta encima de la pantalla, y al
      // cerrarse esa ruta la pantalla vuelve a pedir la lista.
      expect(harness.repository.listCalls, 3);
      expect(harness.repository.filters, [
        const ShiftFilters(),
        const ShiftFilters(),
        const ShiftFilters(weekday: 2),
      ]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('19/10/2026'), findsNothing);

      gate.complete();
      await _settle(tester);
      expect(find.text('Página 1 de 1 · 4 turnos'), findsOneWidget);
      expect(_rowForDate(tester, '20/10/2026')[7], 'Activa');
    },
  );

  testWidgets('Reintentar muestra la carga y oculta el aviso hasta que llega '
      'la respuesta', (tester) async {
    final harness = await _pump(tester);
    _suspendDate(harness, DateTime.utc(2026, 10, 20));
    harness.router.go('/funcionario/llegada');
    await _settle(tester);
    harness.repository.failNextList = true;
    harness.router.go(kShiftsPath);
    await _settle(tester);
    expect(find.text(_visibleListError), findsOneWidget);
    final gate = harness.repository.delayNextList();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Reintentar'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.repository.listCalls, 3);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_visibleListError), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_rowForDate(tester, '20/10/2026')[7], 'Suspendida');
  });

  testWidgets('a 320 px con texto al doble el aviso y Reintentar se ven '
      'dentro del ancho', (tester) async {
    await loadRoboto();
    final harness = await _pump(
      tester,
      size: const Size(320, 800),
      textScale: 2,
    );
    harness.router.go('/funcionario/llegada');
    await _settle(tester);
    harness.repository.failNextList = true;
    harness.router.go(kShiftsPath);
    await _settle(tester);

    final message = find.text(_visibleListError);
    expect(message, findsOneWidget);
    // El escalado se aplica de verdad: 10 puntos pasan a ser 20 y el aviso,
    // que sin escalar entra en una línea de unos 20 px, ocupa varias.
    expect(MediaQuery.textScalerOf(tester.element(message)).scale(10), 20);
    expect(tester.getSize(message).height, greaterThan(40));
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    expect(retry, findsOneWidget);
    final rect = tester.getRect(retry);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 320 px muestra un turno sin excepciones de layout', (
    tester,
  ) async {
    await loadRoboto();
    await _pump(tester, size: const Size(320, 800));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('19/10/2026'), findsWidgets);
  });
}
