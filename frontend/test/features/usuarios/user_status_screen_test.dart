import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/validators/uruguayan_ci_validator.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/providers/account_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/models/account_status_change.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/models/user_filters.dart';
import 'package:agenda_medica/features/usuarios/models/user_page.dart';
import 'package:agenda_medica/features/usuarios/providers/user_filters_controller.dart';
import 'package:agenda_medica/features/usuarios/providers/user_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/user_status_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/users_page_provider.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_correction_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_correction_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_status_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_status_repository.dart';
import 'package:agenda_medica/features/usuarios/screens/user_routes.dart';
import 'package:agenda_medica/features/usuarios/screens/users_screen.dart';
import 'package:agenda_medica/features/usuarios/widgets/users_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import '../cuenta/account_test_support.dart' show RecordingAccountRepository;

// Con la base recortada (ver _trimmedDb) las cuentas, por apellido, son:
// 5 Fernández Diego ADMINISTRADOR (la sesión), 4 Méndez Carla MEDICO,
// 2 Pereira Bruno FUNCIONARIO, 3 Pereira Bruno MEDICO (inactiva),
// 1 Rodríguez Ana SOCIO.

const _wide = Size(1300, 1800);
const _narrow = Size(360, 1800);

typedef _Call = ({int id, bool deactivate});

class _Recording implements UserStatusRepository {
  _Recording(this._delegate);

  final UserStatusRepository _delegate;
  final calls = <_Call>[];
  Completer<void>? gate;
  Object? error;

  Future<AccountStatusChange> _run(
    int id,
    bool deactivate,
    Future<AccountStatusChange> Function() action,
  ) async {
    calls.add((id: id, deactivate: deactivate));
    await gate?.future;
    if (error != null) throw error!;
    return action();
  }

  @override
  Future<AccountStatusChange> deactivate(int id) =>
      _run(id, true, () => _delegate.deactivate(id));

  @override
  Future<AccountStatusChange> reactivate(int id) =>
      _run(id, false, () => _delegate.reactivate(id));
}

class _Users extends FakeUserRepository {
  _Users(super.db, {this.pageSize}) : super(latency: Duration.zero);

  final int? pageSize;
  int listCalls = 0;

  @override
  Future<UserPage> listUsers(UserFilters filters) {
    listCalls++;
    final size = pageSize;
    if (size == null) return super.listUsers(filters);
    return super.listUsers(
      UserFilters(
        role: filters.role,
        status: filters.status,
        query: filters.query,
        order: filters.order,
        ascending: filters.ascending,
        page: filters.page,
        size: size,
      ),
    );
  }
}

/// Solo las cuentas de la semilla con CI de prueba: cinco filas en una página.
FakeAdminDatabase _trimmedDb() {
  final db = FakeAdminDatabase();
  const keep = {'12345672', '23456783', '34567894', '45678905'};
  db.accounts.removeWhere((a) => !keep.contains(a.ci));
  return db;
}

Account _session(String ci, {UserRole role = UserRole.administrador}) =>
    Account(
      ci: ci,
      name: 'Sesión',
      lastName: 'De prueba',
      role: role,
      email: 'sesion@example.org',
      pendingEmail: null,
      phone1: '099000000',
      phone2: null,
      address: 'Calle 1',
    );

final _diego = _session('45678905');

typedef _Harness = ({
  _Recording status,
  _Users users,
  FakeAdminDatabase db,
  ProviderContainer container,
});

Future<_Harness> _pump(
  WidgetTester tester, {
  Size size = _wide,
  RecordingAccountRepository? account,
  FakeAdminDatabase? db,
  int? pageSize,
  _Users? usersOverride,
}) async {
  final database = db ?? _trimmedDb();
  final status = _Recording(
    FakeUserStatusRepository(database, latency: Duration.zero),
  );
  final users = usersOverride ?? _Users(database, pageSize: pageSize);
  final accountRepository =
      account ?? RecordingAccountRepository(account: _diego);
  await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: kUsersPath,
    routes: [GoRoute(path: kUsersPath, builder: (_, _) => const UsersScreen())],
    overrides: [
      userRepositoryProvider.overrideWith((ref) async => users),
      userStatusRepositoryProvider.overrideWith((ref) async => status),
      accountRepositoryProvider.overrideWith((ref) async => accountRepository),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
  final container = ProviderScope.containerOf(
    tester.element(find.byType(UsersScreen)),
  );
  return (status: status, users: users, db: database, container: container);
}

/// Una cuenta de empleado de prueba, creada el [day] de 2026.
FakeAccount _account(
  int id,
  String ci,
  String lastName,
  String firstName,
  DateTime createdAt, {
  AccountStatus status = AccountStatus.active,
  UserRole role = UserRole.funcionario,
}) => FakeAccount(
  id: id,
  ci: ci,
  firstName: firstName,
  lastName: lastName,
  birthDate: DateTime.utc(1990, 1, 1),
  email: '$ci@example.org',
  role: role,
  status: status,
  createdAt: createdAt,
);

/// Una base con exactamente estas cuentas.
FakeAdminDatabase _dbWith(List<FakeAccount> accounts) {
  final db = FakeAdminDatabase();
  db.accounts
    ..clear()
    ..addAll(accounts);
  return db;
}

/// Un padrón cuya página 1 en adelante llega vacía y sin total, como si el
/// servidor ya no tuviera cuentas.
class _EmptyBeyondFirst extends _Users {
  _EmptyBeyondFirst(super.db, {super.pageSize});

  @override
  Future<UserPage> listUsers(UserFilters filters) {
    if (filters.page == 0) return super.listUsers(filters);
    listCalls++;
    return Future.value(
      UserPage(items: const [], page: filters.page, size: 2, total: 0),
    );
  }
}

/// Las cinco cuentas activas del padrón de las pruebas de paginación, por
/// fecha de alta de más nueva a más vieja: Zorrilla (la sesión), Estévez,
/// Duarte, Correa y Benítez.
List<FakeAccount> _fiveActive() => [
  _account(
    5,
    '45678905',
    'Zorrilla',
    'Zoe',
    DateTime.utc(2026, 6, 1),
    role: UserRole.administrador,
  ),
  _account(14, '50000140', 'Estévez', 'Eli', DateTime.utc(2026, 5, 1)),
  _account(13, '50000130', 'Duarte', 'Dani', DateTime.utc(2026, 4, 1)),
  _account(12, '50000120', 'Correa', 'Cora', DateTime.utc(2026, 3, 1)),
  _account(11, '50000110', 'Benítez', 'Beto', DateTime.utc(2026, 2, 1)),
];

/// Activos, por fecha de alta de más nueva a más vieja, de a dos por página,
/// parado en [page].
Future<_Harness> _pumpPaged(
  WidgetTester tester, {
  required FakeAdminDatabase db,
  required AccountStatus status,
  required int page,
  _Users? users,
}) async {
  final h = await _pump(tester, db: db, pageSize: 2, usersOverride: users);
  final filters = h.container.read(userFiltersControllerProvider.notifier);
  filters.search(status: status);
  filters.sortBy(UserOrder.createdAt, ascending: false);
  filters.goToPage(page);
  await tester.pumpAndSettle();
  return h;
}

Finder _pagerButton(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_pagerButton(label)).onPressed != null;

Finder _menu(int id) => find.byKey(Key('user-actions-$id'));
Finder _deactivate(int id) => find.byKey(Key('user-deactivate-$id'));
Finder _reactivate(int id) => find.byKey(Key('user-reactivate-$id'));
final _dialog = find.byKey(const Key('user-status-dialog'));
final _confirm = find.byKey(const Key('user-status-confirm'));
final _cancel = find.byKey(const Key('user-status-cancel'));
final _error = find.byKey(const Key('user-status-error'));
final _help = find.byKey(const Key('user-status-help'));

Future<void> _open(WidgetTester tester, int id) async {
  await tester.ensureVisible(_menu(id));
  await tester.tap(_menu(id));
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, Finder item) async {
  await tester.tap(item);
  await tester.pumpAndSettle();
}

Future<void> _tapConfirm(WidgetTester tester) async {
  await tester.tap(_confirm);
  await tester.pumpAndSettle();
}

/// Los ids que tienen menú, entre los de las cinco cuentas.
List<int> _withMenu() => [
  for (final id in [1, 2, 3, 4, 5])
    if (_menu(id).evaluate().isNotEmpty) id,
];

/// Las claves de las acciones del menú de la cuenta [id], sin abrirlo.
List<Key?> _actionKeys(WidgetTester tester, int id) {
  final menu = tester.widget<PopupMenuButton<Object?>>(_menu(id));
  return [
    for (final entry in menu.itemBuilder(tester.element(_menu(id)))) entry.key,
  ];
}

/// Los ids, entre los de las cinco cuentas, cuyo menú ofrece inactivar o
/// reactivar. Todas las cuentas tienen menú ("Corregir datos"), pero esta
/// acción no se ofrece en socios ni en la fila propia.
List<int> _withStatusAction(WidgetTester tester) => [
  for (final id in [1, 2, 3, 4, 5])
    if (_menu(id).evaluate().isNotEmpty &&
        (_actionKeys(tester, id).contains(Key('user-deactivate-$id')) ||
            _actionKeys(tester, id).contains(Key('user-reactivate-$id'))))
      id,
];

/// Estado de cada fila de la tabla: "Apellido, nombre" y "Activo"/"Inactivo".
List<(String, String)> _tableStates(WidgetTester tester) => [
  for (final row in tester.widget<DataTable>(find.byType(DataTable)).rows)
    ((row.cells[1].child as Text).data!, (row.cells[4].child as Text).data!),
];

String _textOf(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).data!;

VoidCallback? _onPressed(WidgetTester tester, Finder finder) =>
    tester.widget<ButtonStyleButton>(finder).onPressed;

void main() {
  setUpAll(loadRoboto);

  group('quién tiene menú', () {
    for (final (name, size) in [('tabla', _wide), ('tarjetas', _narrow)]) {
      testWidgets('en $name inactivar no se ofrece en Ana ni en Diego', (
        tester,
      ) async {
        await _pump(tester, size: size);

        expect(_withMenu(), [1, 2, 3, 4, 5]);
        expect(_withStatusAction(tester), [2, 3, 4]);
        expect(
          tester.widget<PopupMenuButton<Object?>>(_menu(2)).tooltip,
          'Acciones',
        );
      });
    }

    testWidgets(
      'con la sesión de otro administrador, Diego se puede inactivar',
      (tester) async {
        await _pump(
          tester,
          account: RecordingAccountRepository(account: _session('78901238')),
        );

        expect(_withStatusAction(tester), [2, 3, 4, 5]);
      },
    );

    testWidgets('el mismo CI con otro rol no oculta la acción', (tester) async {
      // La sesión es un administrador con la CI de Bruno: sus cuentas de
      // funcionario y de médico siguen con la acción, y Diego (otra CI)
      // también.
      await _pump(
        tester,
        account: RecordingAccountRepository(account: _session('23456783')),
      );

      expect(_withStatusAction(tester), [2, 3, 4, 5]);
    });

    testWidgets(
      'mientras carga la cuenta de la sesión, sin inactivar en administradores',
      (tester) async {
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        await _pump(
          tester,
          account: RecordingAccountRepository(account: _diego)..gate = gate,
        );

        expect(_withMenu(), [1, 2, 3, 4, 5]);
        expect(_withStatusAction(tester), [2, 3, 4]);
      },
    );

    testWidgets(
      'si falla la cuenta de la sesión, sin inactivar en administradores',
      (tester) async {
        await _pump(
          tester,
          account: RecordingAccountRepository(error: const ApiException()),
        );

        expect(_withMenu(), [1, 2, 3, 4, 5]);
        expect(_withStatusAction(tester), [2, 3, 4]);
      },
    );
  });

  group('el menú y el diálogo', () {
    testWidgets('una cuenta activa ofrece "Inactivar cuenta"', (tester) async {
      await _pump(tester);

      await _open(tester, 2);

      expect(
        _textOf(
          tester,
          find.descendant(of: _deactivate(2), matching: find.byType(Text)),
        ),
        'Inactivar cuenta',
      );
      expect(_reactivate(2), findsNothing);
    });

    testWidgets('una cuenta inactiva ofrece "Reactivar cuenta"', (
      tester,
    ) async {
      await _pump(tester);

      await _open(tester, 3);

      expect(
        _textOf(
          tester,
          find.descendant(of: _reactivate(3), matching: find.byType(Text)),
        ),
        'Reactivar cuenta',
      );
      expect(_deactivate(3), findsNothing);
    });

    testWidgets('elegir "Inactivar" abre el diálogo sin llamar todavía', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _open(tester, 2);

      await _choose(tester, _deactivate(2));

      expect(_dialog, findsOneWidget);
      expect(find.text('¿Inactivar esta cuenta?'), findsOneWidget);
      expect(
        find.text(
          'Bruno Pereira (23456783) no va a poder ingresar y sus sesiones '
          'abiertas se cierran. Sus datos y su historial se conservan. '
          'Podés reactivarla cuando quieras.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Inactivar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
      expect(h.status.calls, isEmpty);
    });

    testWidgets('el diálogo de reactivar dice su texto', (tester) async {
      await _pump(tester);
      await _open(tester, 3);

      await _choose(tester, _reactivate(3));

      expect(find.text('¿Reactivar esta cuenta?'), findsOneWidget);
      expect(
        find.text(
          'Bruno Pereira (23456783) va a poder ingresar de nuevo. Las fechas '
          'de turnos suspendidas siguen suspendidas.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Reactivar'), findsOneWidget);
    });

    testWidgets('Cancelar cierra el diálogo y no llama', (tester) async {
      final h = await _pump(tester);
      await _open(tester, 2);
      await _choose(tester, _deactivate(2));

      await tester.tap(_cancel);
      await tester.pumpAndSettle();

      expect(_dialog, findsNothing);
      expect(h.status.calls, isEmpty);
      expect(_tableStates(tester)[2], ('Pereira, Bruno', 'Activo'));
    });

    testWidgets('tocar fuera del diálogo no lo cierra', (tester) async {
      await _pump(tester);
      await _open(tester, 2);
      await _choose(tester, _deactivate(2));

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(_dialog, findsOneWidget);
    });
  });

  group('confirmar', () {
    testWidgets('inactivar llama una vez, avisa y la fila pasa a "Inactivo"', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(_tableStates(tester), [
        ('Fernández, Diego', 'Activo'),
        ('Méndez, Carla', 'Activo'),
        ('Pereira, Bruno', 'Activo'),
        ('Pereira, Bruno', 'Inactivo'),
        ('Rodríguez, Ana', 'Activo'),
      ]);
      final loadsBefore = h.users.listCalls;
      await _open(tester, 2);
      await _choose(tester, _deactivate(2));

      await _tapConfirm(tester);

      expect(h.status.calls, [(id: 2, deactivate: true)]);
      expect(_dialog, findsNothing);
      expect(find.text('Cuenta inactivada.'), findsOneWidget);
      expect(h.users.listCalls, loadsBefore + 1);
      expect(_tableStates(tester), [
        ('Fernández, Diego', 'Activo'),
        ('Méndez, Carla', 'Activo'),
        ('Pereira, Bruno', 'Inactivo'),
        ('Pereira, Bruno', 'Inactivo'),
        ('Rodríguez, Ana', 'Activo'),
      ]);
    });

    testWidgets('reactivar, con el otro Bruno inactivado antes, funciona', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _open(tester, 2);
      await _choose(tester, _deactivate(2));
      await _tapConfirm(tester);
      expect(h.status.calls, [(id: 2, deactivate: true)]);
      // El aviso anterior sigue en la cola: se espera a que se cierre.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await _open(tester, 3);
      await _choose(tester, _reactivate(3));
      await _tapConfirm(tester);

      expect(h.status.calls, [
        (id: 2, deactivate: true),
        (id: 3, deactivate: false),
      ]);
      expect(find.text('Cuenta reactivada.'), findsOneWidget);
      expect(_tableStates(tester), [
        ('Fernández, Diego', 'Activo'),
        ('Méndez, Carla', 'Activo'),
        ('Pereira, Bruno', 'Inactivo'),
        ('Pereira, Bruno', 'Activo'),
        ('Rodríguez, Ana', 'Activo'),
      ]);
    });

    testWidgets('el filtro, el orden y la página siguen igual después', (
      tester,
    ) async {
      final h = await _pump(tester, pageSize: 1);
      final filters = h.container.read(userFiltersControllerProvider.notifier);
      filters.search(query: 'pereira');
      filters.sortBy(UserOrder.lastName, ascending: false);
      filters.goToPage(1);
      await tester.pumpAndSettle();
      // Descendente: página 1 = Pereira (id 3), página 2 = Pereira (id 2).
      final before = h.container.read(userFiltersControllerProvider);
      expect(before.page, 1);
      expect(_withMenu(), [2]);
      expect(find.text('Página 2 de 2 · 2 cuentas'), findsOneWidget);

      await _open(tester, 2);
      await _choose(tester, _deactivate(2));
      await _tapConfirm(tester);

      expect(h.status.calls, [(id: 2, deactivate: true)]);
      final after = h.container.read(userFiltersControllerProvider);
      expect(after.query, 'pereira');
      expect(after.ascending, isFalse);
      expect(after.page, 1);
      expect(find.text('Página 2 de 2 · 2 cuentas'), findsOneWidget);
      expect(_tableStates(tester), [('Pereira, Bruno', 'Inactivo')]);
    });

    testWidgets('dos toques seguidos hacen una sola llamada', (tester) async {
      final h = await _pump(tester);
      h.status.gate = Completer<void>();
      await _open(tester, 2);
      await _choose(tester, _deactivate(2));

      await tester.tap(_confirm);
      await tester.tap(_confirm);
      await tester.pump();

      expect(h.status.calls, hasLength(1));
      h.status.gate!.complete();
      await tester.pumpAndSettle();
      expect(h.status.calls, hasLength(1));
    });

    testWidgets('con la llamada en curso el diálogo no se cierra', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.status.gate = Completer<void>();
      await _open(tester, 2);
      await _choose(tester, _deactivate(2));
      await tester.tap(_confirm);
      await tester.pump();

      expect(_onPressed(tester, _confirm), isNull);
      expect(_onPressed(tester, _cancel), isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(_dialog, findsOneWidget);

      h.status.gate!.complete();
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
    });
  });

  group('errores', () {
    testWidgets(
      'Carla tiene turnos: el mensaje y la ayuda, con el diálogo abierto',
      (tester) async {
        final h = await _pump(tester);
        final loadsBefore = h.users.listCalls;
        await _open(tester, 4);
        await _choose(tester, _deactivate(4));

        await _tapConfirm(tester);

        expect(_dialog, findsOneWidget);
        expect(
          _textOf(tester, _error),
          'El médico tiene fechas de turnos activas.',
        );
        expect(
          _textOf(tester, _help),
          'Primero hay que suspender las fechas de turnos de este médico y '
          'cancelar sus consultas agendadas.',
        );
        expect(_onPressed(tester, _confirm), isNull);
        expect(_onPressed(tester, _cancel), isNotNull);
        expect(h.users.listCalls, loadsBefore);
        expect(_tableStates(tester)[1], ('Méndez, Carla', 'Activo'));
      },
    );

    testWidgets('médico con consultas agendadas: mismo mensaje y ayuda', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.status.error = const UserStatusException(
        UserStatusFailure.doctorHasAppointments,
        'El médico tiene consultas agendadas.',
      );
      await _open(tester, 4);
      await _choose(tester, _deactivate(4));

      await _tapConfirm(tester);

      expect(_textOf(tester, _error), 'El médico tiene consultas agendadas.');
      expect(
        _textOf(tester, _help),
        'Primero hay que suspender las fechas de turnos de este médico y '
        'cancelar sus consultas agendadas.',
      );
    });

    testWidgets('empleado duplicado: solo el mensaje, sin ayuda repetida', (
      tester,
    ) async {
      await _pump(tester);
      await _open(tester, 3);
      await _choose(tester, _reactivate(3));

      await _tapConfirm(tester);

      expect(_dialog, findsOneWidget);
      expect(
        _textOf(tester, _error),
        'Ya hay otra cuenta de empleado habilitada con esa CI.',
      );
      expect(_help, findsNothing);
    });

    for (final failure in [
      UserStatusFailure.validation,
      UserStatusFailure.other,
    ]) {
      testWidgets('$failure muestra el mensaje del servidor sin ayuda', (
        tester,
      ) async {
        final h = await _pump(tester);
        h.status.error = UserStatusException(failure, 'Mensaje del servidor.');
        await _open(tester, 2);
        await _choose(tester, _deactivate(2));

        await _tapConfirm(tester);

        expect(_dialog, findsOneWidget);
        expect(_textOf(tester, _error), 'Mensaje del servidor.');
        expect(_help, findsNothing);
        expect(_onPressed(tester, _confirm), isNotNull);
      });
    }

    testWidgets('un error sin tipo muestra el mensaje genérico', (
      tester,
    ) async {
      final h = await _pump(tester);
      h.status.error = StateError('no es de la API');
      await _open(tester, 2);
      await _choose(tester, _deactivate(2));

      await _tapConfirm(tester);

      expect(_textOf(tester, _error), kApiGenericMessage);
    });

    for (final (failure, message) in [
      (UserStatusFailure.notFound, 'No se encontró la cuenta.'),
      (UserStatusFailure.alreadyInactive, 'La cuenta ya está inactiva.'),
      (UserStatusFailure.alreadyActive, 'La cuenta ya está activa.'),
    ]) {
      testWidgets('$failure cierra, avisa en un SnackBar y refresca la lista', (
        tester,
      ) async {
        final h = await _pump(tester);
        final loadsBefore = h.users.listCalls;
        h.status.error = UserStatusException(failure, message);
        await _open(tester, 2);
        await _choose(tester, _deactivate(2));

        await _tapConfirm(tester);

        expect(_dialog, findsNothing);
        expect(find.text(message), findsOneWidget);
        expect(h.users.listCalls, loadsBefore + 1);
      });
    }
  });

  group('un rechazo que no cambia reintentando', () {
    for (final size in [const Size(900, 1800), _narrow]) {
      testWidgets('Carla con turnos, a ${size.width} px: confirmar queda '
          'deshabilitado y Cancelar no', (tester) async {
        await _pump(tester, size: size);
        await _open(tester, 4);
        await _choose(tester, _deactivate(4));

        await _tapConfirm(tester);

        expect(_onPressed(tester, _confirm), isNull);
        expect(_onPressed(tester, _cancel), isNotNull);
        expect(
          _textOf(tester, _error),
          'El médico tiene fechas de turnos activas.',
        );
        expect(
          _textOf(tester, _help),
          'Primero hay que suspender las fechas de turnos de este médico y '
          'cancelar sus consultas agendadas.',
        );
      });

      testWidgets('Bruno duplicado, a ${size.width} px: confirmar queda '
          'deshabilitado y el mensaje sale una sola vez', (tester) async {
        await _pump(tester, size: size);
        await _open(tester, 3);
        await _choose(tester, _reactivate(3));

        await _tapConfirm(tester);

        expect(_onPressed(tester, _confirm), isNull);
        expect(_onPressed(tester, _cancel), isNotNull);
        expect(
          find.text('Ya hay otra cuenta de empleado habilitada con esa CI.'),
          findsOneWidget,
        );
        expect(_help, findsNothing);
        expect(
          find.textContaining('Ya hay otra cuenta de empleado'),
          findsOneWidget,
        );
      });

      for (final failure in [
        UserStatusFailure.validation,
        UserStatusFailure.other,
      ]) {
        testWidgets('$failure, a ${size.width} px: se puede reintentar', (
          tester,
        ) async {
          final h = await _pump(tester, size: size);
          h.status.error = UserStatusException(failure, 'Falló un momento.');
          await _open(tester, 2);
          await _choose(tester, _deactivate(2));
          await _tapConfirm(tester);
          expect(_textOf(tester, _error), 'Falló un momento.');
          expect(_onPressed(tester, _confirm), isNotNull);

          h.status.error = null;
          await _tapConfirm(tester);

          expect(h.status.calls.length, 2);
          expect(_dialog, findsNothing);
          expect(find.text('Cuenta inactivada.'), findsOneWidget);
        });
      }
    }

    testWidgets('cerrar con el error y reabrir empieza limpio', (tester) async {
      final h = await _pump(tester);
      await _open(tester, 4);
      await _choose(tester, _deactivate(4));
      await _tapConfirm(tester);
      expect(_error, findsOneWidget);
      expect(_onPressed(tester, _confirm), isNull);

      await tester.tap(_cancel);
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
      await _open(tester, 4);
      await _choose(tester, _deactivate(4));

      expect(_dialog, findsOneWidget);
      expect(_error, findsNothing);
      expect(_help, findsNothing);
      expect(_onPressed(tester, _confirm), isNotNull);
      expect(h.status.calls.length, 1);
    });
  });

  group('la página que queda vacía', () {
    testWidgets(
      'la última con una sola cuenta: vuelve a la anterior con el filtro y el '
      'orden',
      (tester) async {
        await _pumpPaged(
          tester,
          db: _dbWith(_fiveActive()),
          status: AccountStatus.active,
          page: 2,
        );
        expect(find.text('Página 3 de 3 · 5 cuentas'), findsOneWidget);
        expect(find.text('Benítez, Beto'), findsOneWidget);

        await _open(tester, 11);
        await _choose(tester, _deactivate(11));
        await _tapConfirm(tester);

        expect(
          find.text(
            'No se encontraron usuarios con esos filtros. '
            'Cambiá los criterios y volvé a buscar.',
          ),
          findsNothing,
        );
        expect(find.text('Página 2 de 2 · 4 cuentas'), findsOneWidget);
        expect(find.text('Duarte, Dani'), findsOneWidget);
        expect(find.text('Correa, Cora'), findsOneWidget);
        // El orden es el de fecha de alta descendente: Duarte antes que Correa.
        expect(
          tester.getTopLeft(find.text('Duarte, Dani')).dy,
          lessThan(tester.getTopLeft(find.text('Correa, Cora')).dy),
        );
        // El filtro "Activo" sigue: ni la recién inactivada ni las de la
        // primera página.
        expect(find.text('Benítez, Beto'), findsNothing);
        expect(find.text('Estévez, Eli'), findsNothing);
        expect(find.text('Zorrilla, Zoe'), findsNothing);
        expect(_enabled(tester, 'Anterior'), isTrue);
        expect(_enabled(tester, 'Siguiente'), isFalse);
      },
    );

    testWidgets(
      'si era la única cuenta, dice que no hay usuarios y no hay Anterior',
      (tester) async {
        final h = await _pump(
          tester,
          db: _dbWith([
            _account(
              5,
              '45678905',
              'Zorrilla',
              'Zoe',
              DateTime.utc(2026, 6, 1),
              role: UserRole.administrador,
            ),
            _account(
              11,
              '50000110',
              'Benítez',
              'Beto',
              DateTime.utc(2026, 2, 1),
            ),
          ]),
          pageSize: 2,
        );
        h.container
            .read(userFiltersControllerProvider.notifier)
            .search(status: AccountStatus.active, query: 'Benitez');
        await tester.pumpAndSettle();
        expect(find.text('Benítez, Beto'), findsOneWidget);

        await _open(tester, 11);
        await _choose(tester, _deactivate(11));
        await _tapConfirm(tester);

        expect(
          find.text(
            'No se encontraron usuarios con esos filtros. Cambiá los criterios '
            'y volvé a buscar.',
          ),
          findsOneWidget,
        );
        expect(find.text('Anterior'), findsNothing);
      },
    );

    testWidgets('si el padrón queda sin cuentas, dice que no hay usuarios y no '
        'muestra Anterior ni vuelve a pedir', (tester) async {
      final db = _dbWith(_fiveActive());
      final users = _EmptyBeyondFirst(db, pageSize: 2);
      await _pumpPaged(
        tester,
        db: db,
        status: AccountStatus.active,
        page: 2,
        users: users,
      );

      expect(
        find.text(
          'No se encontraron usuarios con esos filtros. '
          'Cambiá los criterios y volvé a buscar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Anterior'), findsNothing);
      expect(find.text('Siguiente'), findsNothing);
    });

    testWidgets(
      'una página del medio que queda con menos cuentas no se mueve',
      (tester) async {
        await _pumpPaged(
          tester,
          db: _dbWith(_fiveActive()),
          status: AccountStatus.active,
          page: 1,
        );
        expect(find.text('Duarte, Dani'), findsOneWidget);
        expect(find.text('Correa, Cora'), findsOneWidget);

        await _open(tester, 12);
        await _choose(tester, _deactivate(12));
        await _tapConfirm(tester);

        // Quedan Zorrilla, Estévez, Duarte y Benítez: la página 2 trae a Duarte
        // y Benítez.
        expect(find.text('Página 2 de 2 · 4 cuentas'), findsOneWidget);
        expect(find.text('Duarte, Dani'), findsOneWidget);
        expect(find.text('Benítez, Beto'), findsOneWidget);
        expect(find.text('Correa, Cora'), findsNothing);
      },
    );

    testWidgets(
      'al reactivar la última cuenta con el filtro "Inactivo", vuelve '
      'a la anterior',
      (tester) async {
        await _pumpPaged(
          tester,
          db: _dbWith([
            _account(
              5,
              '45678905',
              'Zorrilla',
              'Zoe',
              DateTime.utc(2026, 6, 1),
              role: UserRole.administrador,
            ),
            _account(
              20,
              '50000200',
              'Gómez',
              'Gus',
              DateTime.utc(2026, 1, 1),
              status: AccountStatus.inactive,
            ),
            _account(
              21,
              '50000210',
              'Herrera',
              'Hugo',
              DateTime.utc(2026, 2, 1),
              status: AccountStatus.inactive,
            ),
            _account(
              22,
              '50000220',
              'Iglesias',
              'Ines',
              DateTime.utc(2026, 3, 1),
              status: AccountStatus.inactive,
            ),
          ]),
          status: AccountStatus.inactive,
          page: 1,
        );
        expect(find.text('Página 2 de 2 · 3 cuentas'), findsOneWidget);
        expect(find.text('Gómez, Gus'), findsOneWidget);

        await _open(tester, 20);
        await _choose(tester, _reactivate(20));
        await _tapConfirm(tester);

        expect(find.text('Página 1 de 1 · 2 cuentas'), findsOneWidget);
        expect(find.text('Iglesias, Ines'), findsOneWidget);
        expect(find.text('Herrera, Hugo'), findsOneWidget);
        expect(find.text('Gómez, Gus'), findsNothing);
        expect(_enabled(tester, 'Anterior'), isFalse);
      },
    );
  });

  group('Corregir datos', () {
    for (final (name, size) in [('tabla', _wide), ('tarjetas', _narrow)]) {
      testWidgets(
        'en $name toda fila lo ofrece primero, también socios y la propia',
        (tester) async {
          await _pump(tester, size: size);

          for (final id in [1, 2, 3, 4, 5]) {
            expect(
              _actionKeys(tester, id).first,
              Key('user-edit-$id'),
              reason: 'cuenta $id',
            );
          }
        },
      );
    }

    testWidgets('el ítem se llama "Corregir datos"', (tester) async {
      await _pump(tester);

      await _open(tester, 1);

      expect(find.text('Corregir datos'), findsOneWidget);
    });

    testWidgets('sin saber quién es la sesión también se ofrece', (
      tester,
    ) async {
      await _pump(
        tester,
        account: RecordingAccountRepository(error: const ApiException()),
      );

      expect(_actionKeys(tester, 5).first, const Key('user-edit-5'));
      expect(_actionKeys(tester, 1).first, const Key('user-edit-1'));
    });
  });

  group('la fila propia', () {
    // LIMITACIÓN CONOCIDA: la fila propia se reconoce por CI y rol, y la sesión
    // no guarda el id de la cuenta. Si el administrador corrige la CI de su
    // propia cuenta, la sesión (la cuenta de `GET /api/cuentas/me`) conserva la
    // CI vieja hasta que se renueve, el padrón ya trae la nueva con el mismo id
    // y la fila propia deja de reconocerse: ofrece "Inactivar cuenta". Una
    // tarjeta aparte lo resuelve cuando el backend entregue el id.
    testWidgets(
      'LIMITACIÓN: al corregir mi propia CI, mi fila ofrece inactivar',
      (tester) async {
        final h = await _pump(
          tester,
          account: RecordingAccountRepository(account: _diego),
        );
        // Antes de corregir, la fila propia (id 5) no ofrece inactivar.
        expect(_withStatusAction(tester), [2, 3, 4]);

        // Una cédula libre y válida; el dígito verificador es un dato de entrada.
        const body = '3644426';
        final newCi = '$body${calculateUruguayanCiVerifierDigit(body)}';
        // Fuera del reloj falso del test: el fake espera con un Future.delayed.
        await tester.runAsync(
          () => FakeUserCorrectionRepository(
            h.db,
            latency: Duration.zero,
          ).correct(5, AccountCorrection(ci: newCi)),
        );
        h.container.invalidate(usersPageProvider);
        await tester.pumpAndSettle();

        // La sesión conserva la CI vieja.
        expect(h.container.read(accountProvider).value?.ci, '45678905');
        // El padrón ya trae la nueva, con el mismo id de cuenta.
        expect(h.db.accounts.firstWhere((a) => a.id == 5).ci, newCi);
        // La fila propia ya no se reconoce: ofrece inactivar.
        expect(_withStatusAction(tester), [2, 3, 4, 5]);
        expect(
          _actionKeys(tester, 5),
          contains(const Key('user-deactivate-5')),
        );
        // La corrección sigue disponible en esa fila.
        expect(_actionKeys(tester, 5).first, const Key('user-edit-5'));
      },
    );

    // PENDIENTE: la sesión no guarda el id de la cuenta y GET /api/cuentas/me
    // tampoco lo devuelve, así que hoy la fila propia solo se reconoce por CI
    // y rol. Cuando la sesión tenga el id, hay que reconocerla por id y sacar
    // el `skip`. testWidgets solo admite `skip: true`, por eso el motivo va en
    // el nombre y en este comentario.
    testWidgets('PENDIENTE (falta el id de la cuenta en la sesión): si otro '
        'administrador corrige mi CI, mi fila no ofrece inactivar', (
      tester,
    ) async {
      // La sesión quedó con la CI vieja (45678905); el padrón ya trae la
      // nueva (45678906) con el mismo id de cuenta (5).
      await _pump(
        tester,
        db: _dbWith([
          _account(
            5,
            '45678906',
            'Zorrilla',
            'Zoe',
            DateTime.utc(2026, 6, 1),
            role: UserRole.administrador,
          ),
          _account(11, '50000110', 'Benítez', 'Beto', DateTime.utc(2026, 2, 1)),
        ]),
        account: RecordingAccountRepository(account: _session('45678905')),
      );

      expect(_menu(11), findsOneWidget);
      expect(_menu(5), findsNothing);
    }, skip: true);
  });

  group('según el ancho', () {
    // El contenido del padrón mide el ancho de la pantalla menos 24 px a cada
    // lado (CenteredContent): la tabla entra con ese ancho >= kUsersTableMinWidth.
    final atLimit = kUsersTableMinWidth + 48;

    testWidgets('justo en el límite se muestra la tabla sin desplazarla', (
      tester,
    ) async {
      await _pump(tester, size: Size(atLimit, 1800));

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(_menu(2), findsOneWidget);
      expect(tester.takeException(), isNull);
      final horizontal = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      final scrollable = find.descendant(
        of: horizontal,
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
    });

    testWidgets('un píxel por debajo del límite se muestran tarjetas', (
      tester,
    ) async {
      await _pump(tester, size: Size(atLimit - 1, 1800));

      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(Card), findsNWidgets(5));
      expect(_menu(2), findsOneWidget);
    });

    testWidgets('el límite es la tabla medida con Roboto más ~7 %', (
      tester,
    ) async {
      // La semilla completa, como la medición del límite: 947 px medidos a
      // mano con la columna "Acciones" (864 sin ella).
      await _pump(tester, size: _wide, db: FakeAdminDatabase());

      final tableWidth = tester.getSize(find.byType(DataTable)).width;
      expect(tableWidth, closeTo(947, 1.5));
      expect(kUsersTableMinWidth, 1014);
      expect(tableWidth * 1.08, greaterThan(kUsersTableMinWidth));
    });
  });

  group('a 320 px con Roboto', () {
    const phone = Size(320, 1800);

    testWidgets('las tarjetas con el menú no desbordan', (tester) async {
      await _pump(tester, size: phone);

      expect(_menu(2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el menú abierto y el diálogo no desbordan', (tester) async {
      await _pump(tester, size: phone);
      await _open(tester, 3);
      expect(tester.takeException(), isNull);
      await _choose(tester, _reactivate(3));
      expect(_dialog, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el diálogo con el error y la ayuda visibles no desborda', (
      tester,
    ) async {
      await _pump(tester, size: phone);
      await _open(tester, 4);
      await _choose(tester, _deactivate(4));
      await _tapConfirm(tester);

      expect(_error, findsOneWidget);
      expect(_help, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con el botón deshabilitado y el error visible no desborda', (
      tester,
    ) async {
      await _pump(tester, size: phone);
      await _open(tester, 3);
      await _choose(tester, _reactivate(3));
      await _tapConfirm(tester);

      expect(_error, findsOneWidget);
      expect(_onPressed(tester, _confirm), isNull);
      expect(_onPressed(tester, _cancel), isNotNull);
      expect(tester.takeException(), isNull);
    });
  });
}
