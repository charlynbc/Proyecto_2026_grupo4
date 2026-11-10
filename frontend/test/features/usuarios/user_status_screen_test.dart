import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/models/account_status_change.dart';
import 'package:agenda_medica/features/usuarios/models/user_filters.dart';
import 'package:agenda_medica/features/usuarios/models/user_page.dart';
import 'package:agenda_medica/features/usuarios/providers/user_filters_controller.dart';
import 'package:agenda_medica/features/usuarios/providers/user_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/user_status_repository_provider.dart';
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
}) async {
  final database = db ?? _trimmedDb();
  final status = _Recording(
    FakeUserStatusRepository(database, latency: Duration.zero),
  );
  final users = _Users(database, pageSize: pageSize);
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
      testWidgets('en $name no hay menú en Ana ni en Diego y sí en los demás', (
        tester,
      ) async {
        await _pump(tester, size: size);

        expect(_withMenu(), [2, 3, 4]);
        expect(
          tester.widget<PopupMenuButton<Object?>>(_menu(2)).tooltip,
          'Acciones',
        );
      });
    }

    testWidgets('con la sesión de otro administrador, Diego tiene menú', (
      tester,
    ) async {
      await _pump(
        tester,
        account: RecordingAccountRepository(account: _session('78901238')),
      );

      expect(_withMenu(), [2, 3, 4, 5]);
    });

    testWidgets('el mismo CI con otro rol no oculta el menú', (tester) async {
      // La sesión es un administrador con la CI de Bruno: sus cuentas de
      // funcionario y de médico siguen con menú, y Diego (otra CI) también.
      await _pump(
        tester,
        account: RecordingAccountRepository(account: _session('23456783')),
      );

      expect(_withMenu(), [2, 3, 4, 5]);
    });

    testWidgets(
      'mientras carga la cuenta de la sesión, sin menú en administradores',
      (tester) async {
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        await _pump(
          tester,
          account: RecordingAccountRepository(account: _diego)..gate = gate,
        );

        expect(_withMenu(), [2, 3, 4]);
      },
    );

    testWidgets(
      'si falla la cuenta de la sesión, sin menú en administradores',
      (tester) async {
        await _pump(
          tester,
          account: RecordingAccountRepository(error: const ApiException()),
        );

        expect(_withMenu(), [2, 3, 4]);
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
        expect(_onPressed(tester, _confirm), isNotNull);
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

    testWidgets('empleado duplicado: el mensaje y su ayuda', (tester) async {
      await _pump(tester);
      await _open(tester, 3);
      await _choose(tester, _reactivate(3));

      await _tapConfirm(tester);

      expect(_dialog, findsOneWidget);
      expect(
        _textOf(tester, _error),
        'Ya hay otra cuenta de empleado habilitada con esa CI.',
      );
      expect(
        _textOf(tester, _help),
        'Ya hay otra cuenta de empleado habilitada con esta CI.',
      );
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
  });
}
