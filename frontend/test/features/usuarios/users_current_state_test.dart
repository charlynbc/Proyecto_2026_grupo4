import 'dart:async';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:agenda_medica/features/novedades/providers/announcements_provider.dart';
import 'package:agenda_medica/features/usuarios/models/role_label.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/models/user_filters.dart';
import 'package:agenda_medica/features/usuarios/models/user_page.dart';
import 'package:agenda_medica/features/usuarios/providers/user_filters_controller.dart';
import 'package:agenda_medica/features/usuarios/providers/user_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/user_status_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_status_repository.dart';
import 'package:agenda_medica/features/usuarios/screens/user_routes.dart';
import 'package:agenda_medica/features/usuarios/screens/users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/app_lifecycle.dart';
import '../../helpers/load_roboto.dart';

const _loadFailure = 'Fallo controlado al actualizar los usuarios.';
const _visibleListError = 'No pudimos cargar los usuarios. Intentá de nuevo.';
const _otherSection = kClinicsPath;

class _AdminSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    status: SessionStatus.authenticated,
    accessToken: 'usuarios-estado-actual-prueba',
    role: UserRole.administrador,
  );
}

class _ControlledUserRepository extends FakeUserRepository {
  _ControlledUserRepository(super.db) : super(latency: Duration.zero);

  final filters = <UserFilters>[];
  bool failNextList = false;
  Completer<void>? _nextGate;
  Completer<void>? _activeGate;

  int get listCalls => filters.length;

  /// Frena el próximo pedido de la lista, sea cual sea.
  Completer<void> delayNextList() {
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
  Future<UserPage> listUsers(UserFilters query) async {
    filters.add(query);
    final gate = _nextGate;
    _nextGate = null;
    if (gate != null) {
      _activeGate = gate;
      await gate.future;
      _activeGate = null;
    }
    if (failNextList) {
      failNextList = false;
      throw const ApiException(_loadFailure);
    }
    return super.listUsers(query);
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
  final FakeAdminDatabase database;
  final _ControlledUserRepository repository;
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = const Size(1600, 1800),
  double textScale = 1,
  bool failFirstList = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final database = FakeAdminDatabase();
  final repository = _ControlledUserRepository(database)
    ..failNextList = failFirstList;
  final container = ProviderContainer(
    overrides: [
      useFakesProvider.overrideWithValue(true),
      sessionProvider.overrideWith(_AdminSession.new),
      fakeAdminDatabaseProvider.overrideWithValue(database),
      userRepositoryProvider.overrideWith((ref) async => repository),
      userStatusRepositoryProvider.overrideWith(
        (ref) async =>
            FakeUserStatusRepository(database, latency: Duration.zero),
      ),
      latestAnnouncementsProvider.overrideWith((ref) async => []),
    ],
  );
  final router = container.read(goRouterProvider)..go(kUsersPath);
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
  // La cuenta de la sesión falsa tarda 300 ms, y un temporizador no cuenta
  // como cuadro pendiente: sin este avance quedaría vivo al terminar.
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(UsersScreen), findsOneWidget);

  return _Harness(
    container: container,
    router: router,
    database: database,
    repository: repository,
  );
}

/// Las filas de la tabla como "Apellido, nombre" (segunda columna).
List<String> _names(WidgetTester tester) => [
  for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
    (row.cells[1].child as Text).data!,
];

/// El estado ("Activo" o "Inactivo", quinta columna) de la cuenta de la CI
/// [ci] con el rol [role]: hay dos cuentas con la CI 23456783.
String _statusOf(WidgetTester tester, String ci, UserRole role) {
  final row = tester
      .widget<DataTable>(find.byType(DataTable))
      .rows
      .singleWhere(
        (row) =>
            (row.cells[0].child as Text).data == ci &&
            (row.cells[2].child as Text).data == roleLabel(role),
      );
  return (row.cells[4].child as Text).data!;
}

/// Otro administrador da de alta a una socia mientras esta pantalla no mira.
/// Por apellido queda primera de la lista.
void _addOtherAdminAccount(_Harness harness) {
  harness.database.accounts.add(
    FakeAccount(
      id: harness.database.newAccountId(),
      ci: '31415926',
      firstName: 'Rocío',
      lastName: 'Abreu',
      birthDate: DateTime.utc(1991, 5, 17),
      email: 'rocio.abreu@example.org',
      role: UserRole.socio,
      createdAt: DateTime.utc(2026, 11, 24),
    ),
  );
}

Future<void> _leave(WidgetTester tester, _Harness harness) async {
  harness.router.go(_otherSection);
  await _settle(tester);
}

Future<void> _pumpUntilListCalls(
  WidgetTester tester,
  _ControlledUserRepository repository,
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

Future<void> _choose(
  WidgetTester tester,
  Finder dropdown,
  String option,
) async {
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Finder get _roleFilter => find.byType(DropdownButtonFormField<UserRole?>);
Finder get _statusFilter => find.byWidgetPredicate(
  (w) =>
      w is DropdownButtonFormField &&
      w.runtimeType.toString().contains('AccountStatus'),
);

Future<void> _search(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Buscar');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  // Los anchos se miden con la tipografía real, no con Ahem.
  setUpAll(loadRoboto);

  testWidgets('al volver desde otra sección muestra la cuenta nueva', (
    tester,
  ) async {
    final harness = await _pump(tester);
    expect(find.text('Página 1 de 2 · 25 cuentas'), findsOneWidget);
    expect(_names(tester).first, 'Acosta, Florencia');

    await _leave(tester, harness);
    _addOtherAdminAccount(harness);
    harness.router.go(kUsersPath);
    await _settle(tester);

    expect(_names(tester).first, 'Abreu, Rocío');
    expect(find.text('31415926'), findsOneWidget);
    expect(find.text('Página 1 de 2 · 26 cuentas'), findsOneWidget);
  });

  testWidgets('al volver hace un pedido y conserva la lista durante la carga', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _leave(tester, harness);
    _addOtherAdminAccount(harness);
    final gate = harness.repository.delayNextList();

    harness.router.go(kUsersPath);
    await _pumpUntilListCalls(tester, harness.repository, 2);

    // Cuenta la carga inicial y el único pedido al volver.
    expect(harness.repository.listCalls, 2);
    // La lista anterior sigue visible y sin indicador de carga.
    expect(_names(tester).first, 'Acosta, Florencia');
    expect(find.byType(CircularProgressIndicator), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(harness.repository.listCalls, 2);
    expect(_names(tester).first, 'Abreu, Rocío');
  });

  testWidgets('al volver del segundo plano pide una vez y muestra lo nuevo', (
    tester,
  ) async {
    final harness = await _pump(tester);
    _addOtherAdminAccount(harness);

    backgroundAndReturn(tester);
    await _settle(tester);

    expect(harness.repository.listCalls, 2);
    expect(_names(tester).first, 'Abreu, Rocío');
    expect(find.text('Página 1 de 2 · 26 cuentas'), findsOneWidget);
  });

  testWidgets('si falla al volver ofrece Reintentar y este muestra la carga', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _leave(tester, harness);
    _addOtherAdminAccount(harness);
    harness.repository.failNextList = true;

    harness.router.go(kUsersPath);
    await _settle(tester);

    // Al volver se hizo un segundo pedido y su falla se muestra enseguida.
    expect(harness.repository.listCalls, 2);
    expect(find.text(_visibleListError), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    expect(retry, findsOneWidget);
    final gate = harness.repository.delayNextList();

    await tester.tap(retry);
    await tester.pump(const Duration(milliseconds: 100));

    expect(harness.repository.listCalls, 3);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(_visibleListError), findsNothing);

    gate.complete();
    await _settle(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_names(tester).first, 'Abreu, Rocío');
  });

  testWidgets('si falla la carga inicial el aviso aparece enseguida y con un '
      'solo pedido', (tester) async {
    final harness = await _pump(tester, failFirstList: true);

    // Sin reintento automático: un pedido, y el aviso ya está a la vista.
    expect(harness.repository.listCalls, 1);
    expect(find.text(_visibleListError), findsOneWidget);
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    expect(retry, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(retry);
    await _settle(tester);
    expect(harness.repository.listCalls, 2);
    expect(find.text(_visibleListError), findsNothing);
    expect(_names(tester).first, 'Acosta, Florencia');
  });

  testWidgets('al volver conserva rol, estado y texto aplicados', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _choose(tester, _roleFilter, 'Socio');
    await _choose(tester, _statusFilter, 'Activo');
    await tester.enterText(find.byType(TextField), 'ez');
    await _search(tester);
    const applied = UserFilters(
      role: UserRole.socio,
      status: AccountStatus.active,
      query: 'ez',
    );
    expect(harness.container.read(userFiltersControllerProvider), applied);
    expect(find.text('Página 1 de 1 · 11 cuentas'), findsOneWidget);

    await _leave(tester, harness);
    final callsBeforeReturn = harness.repository.listCalls;
    harness.router.go(kUsersPath);
    await _settle(tester);

    expect(harness.repository.listCalls, callsBeforeReturn + 1);
    expect(harness.repository.filters.last, applied);
    expect(harness.container.read(userFiltersControllerProvider), applied);
    expect(find.text('Página 1 de 1 · 11 cuentas'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButtonFormField<UserRole?>>(_roleFilter)
          .initialValue,
      UserRole.socio,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'ez',
    );
  });

  testWidgets('con la página 2 elegida, al volver sigue en la 2', (
    tester,
  ) async {
    final harness = await _pump(tester);
    final next = find.text('Siguiente');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await _settle(tester);
    expect(find.text('Página 2 de 2 · 25 cuentas'), findsOneWidget);
    expect(_names(tester), hasLength(5));

    await _leave(tester, harness);
    _addOtherAdminAccount(harness);
    harness.router.go(kUsersPath);
    await _settle(tester);

    expect(harness.repository.filters.last.page, 1);
    expect(find.text('Página 2 de 2 · 26 cuentas'), findsOneWidget);
    expect(_names(tester), hasLength(6));
  });

  testWidgets(
    'al cambiar un filtro muestra carga en vez de la lista anterior',
    (tester) async {
      final harness = await _pump(tester);
      await _choose(tester, _statusFilter, 'Inactivo');
      final gate = harness.repository.delayNextList();
      final search = find.widgetWithText(FilledButton, 'Buscar');
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Acosta, Florencia'), findsNothing);

      gate.complete();
      await _settle(tester);
      expect(find.text('Página 1 de 1 · 4 cuentas'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('inactivar una cuenta y volver muestra la fila inactiva', (
    tester,
  ) async {
    final harness = await _pump(tester);
    expect(_statusOf(tester, '23456783', UserRole.funcionario), 'Activo');

    await tester.tap(find.byKey(const Key('user-actions-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-deactivate-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-status-confirm')));
    await _settle(tester);
    expect(find.text('Cuenta inactivada.'), findsOneWidget);
    expect(_statusOf(tester, '23456783', UserRole.funcionario), 'Inactivo');

    await _leave(tester, harness);
    harness.router.go(kUsersPath);
    await _settle(tester);

    expect(_statusOf(tester, '23456783', UserRole.funcionario), 'Inactivo');
    await tester.tap(find.byKey(const Key('user-actions-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('user-reactivate-2')), findsOneWidget);
    expect(find.byKey(const Key('user-deactivate-2')), findsNothing);
  });

  testWidgets('una fila vieja que otro inactivó se maneja al confirmar', (
    tester,
  ) async {
    final harness = await _pump(tester);
    await _leave(tester, harness);
    // Otro administrador inactiva la cuenta mientras esta lista no mira.
    await tester.runAsync(
      () => FakeUserStatusRepository(
        harness.database,
        latency: Duration.zero,
      ).deactivate(2),
    );
    final gate = harness.repository.delayNextList();

    harness.router.go(kUsersPath);
    await _pumpUntilListCalls(tester, harness.repository, 2);

    // Mientras llega la lista nueva se ve la fila vieja, con su menú.
    expect(_statusOf(tester, '23456783', UserRole.funcionario), 'Activo');
    await tester.tap(find.byKey(const Key('user-actions-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-deactivate-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user-status-confirm')));
    await _settle(tester);

    // El servidor dice que ya estaba inactiva: aviso y lista nueva.
    expect(find.text('La cuenta ya está inactiva.'), findsOneWidget);
    expect(find.byKey(const Key('user-status-dialog')), findsNothing);
    expect(_statusOf(tester, '23456783', UserRole.funcionario), 'Inactivo');
    gate.complete();
    await _settle(tester);
    expect(_statusOf(tester, '23456783', UserRole.funcionario), 'Inactivo');
  });

  testWidgets('a 320 px con texto al doble el aviso y Reintentar se ven '
      'dentro del ancho', (tester) async {
    final harness = await _pump(
      tester,
      size: const Size(320, 800),
      textScale: 2,
    );
    await _leave(tester, harness);
    harness.repository.failNextList = true;
    harness.router.go(kUsersPath);
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

  testWidgets('a 1300 px muestra la tabla sin excepciones de layout', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1300, 1800));

    expect(find.byType(DataTable), findsOneWidget);
    expect(_names(tester).first, 'Acosta, Florencia');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a 1100 px con el menú lateral usa tarjetas sin desbordes', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1100, 1800));

    // El menú lateral le quita ancho al listado: queda por debajo de los
    // 1014 px de la tabla y cada cuenta es una tarjeta.
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Acosta, Florencia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
