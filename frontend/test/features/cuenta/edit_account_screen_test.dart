import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/forms/phone_field_rules.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/models/account_changes.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/cuenta/repositories/account_repository.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:agenda_medica/features/cuenta/screens/account_screen.dart';
import 'package:agenda_medica/features/cuenta/screens/edit_account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import 'account_test_support.dart';

const _shortNotice = 'Guardamos tus datos.';
const _longNotice =
    'Guardamos tus datos. El cambio de correo a nuevo@example.org está '
    'pendiente de confirmación. Revisá esa casilla y abrí el enlace dentro '
    'de las 24 horas. Hasta entonces, seguís usando lucia@example.org.';

class _EditRepository extends RecordingAccountRepository {
  _EditRepository({super.account, super.error, this.result, this.saveError});

  final Account? result;
  final Object? saveError;
  final updates = <Map<String, Object?>>[];
  Completer<void>? saveGate;

  @override
  Future<Account> update(AccountChanges changes) async {
    updates.add(changes.toJson());
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    return result ?? lucia();
  }
}

Future<GoRouter> _pump(
  WidgetTester tester,
  _EditRepository repo, {
  Size size = const Size(800, 900),
}) => pumpAdminScreens(
  tester,
  routes: [
    GoRoute(path: kAccountPath, builder: (_, _) => const AccountScreen()),
    GoRoute(
      path: kAccountEditPath,
      builder: (_, _) => const EditAccountScreen(),
    ),
    GoRoute(
      path: '/encima',
      builder: (_, _) => const Scaffold(body: Text('Otra pantalla')),
    ),
  ],
  initialLocation: kAccountEditPath,
  overrides: [accountRepositoryProvider.overrideWith((ref) async => repo)],
  size: size,
);

Finder _field(String name) => find.byKey(Key('edit-$name'));
final _save = find.byKey(const Key('edit-save'));
final _saved = find.byKey(const Key('edit-saved'));

Future<void> _enter(WidgetTester tester, String name, String value) async {
  await tester.ensureVisible(_field(name));
  await tester.enterText(_field(name), value);
  await tester.pump();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(_save);
  await tester.tap(_save);
  await tester.pumpAndSettle();
}

String _value(WidgetTester tester, String name) =>
    tester.widget<TextFormField>(_field(name)).controller!.text;

void main() {
  setUpAll(loadRoboto);

  testWidgets('precarga solo los cuatro campos editables', (tester) async {
    final repo = _EditRepository();
    await _pump(tester, repo);

    expect(find.text('Editar mis datos'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(_value(tester, 'address'), 'Av. 18 de Julio 1234, Montevideo');
    expect(_value(tester, 'phone1'), '099123456');
    expect(_value(tester, 'phone2'), '');
    expect(_value(tester, 'email'), 'lucia@example.org');
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    await _tapSave(tester);
    expect(repo.updates, isEmpty);
  });

  testWidgets('espacios en la dirección no habilitan un guardado', (
    tester,
  ) async {
    final repo = _EditRepository();
    await _pump(tester, repo);
    await _enter(tester, 'address', '  Av. 18 de Julio 1234, Montevideo  ');

    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    expect(repo.updates, isEmpty);
  });

  testWidgets('el correo actual con otras mayúsculas no se envía', (
    tester,
  ) async {
    final repo = _EditRepository();
    await _pump(tester, repo);
    await _enter(tester, 'email', 'LUCIA@example.org');

    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    expect(repo.updates, isEmpty);
  });

  testWidgets('un callback anterior no guarda si ya no hay cambios', (
    tester,
  ) async {
    final repo = _EditRepository();
    final router = await _pump(tester, repo);
    await _enter(tester, 'address', 'Av. Italia 1234');
    final staleSave = tester.widget<FilledButton>(_save).onPressed;
    expect(staleSave, isNotNull);

    await _enter(tester, 'address', 'Av. 18 de Julio 1234, Montevideo');
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    staleSave!();
    await tester.pumpAndSettle();

    expect(repo.updates, isEmpty);
    expect(locationOf(router), kAccountEditPath);
  });

  testWidgets('solo manda el cambio recortado y muestra el aviso corto', (
    tester,
  ) async {
    final repo = _EditRepository(
      result: Account.fromJson({
        ...luciaJson(),
        'direccion': 'Av. Italia 1234',
      }),
    );
    final router = await _pump(tester, repo);
    await _enter(tester, 'address', '  Av. Italia 1234  ');
    await _enter(tester, 'email', '  lucia@example.org  ');
    await _tapSave(tester);

    expect(repo.updates, [
      {'direccion': 'Av. Italia 1234'},
    ]);
    expect(locationOf(router), '/cuenta');
    expect(textOf(tester, 'account-address'), 'Av. Italia 1234');
    expect(repo.calls, 1);
    expect(_saved, findsOneWidget);
    expect(find.text(_shortNotice), findsOneWidget);
  });

  testWidgets('si se borra un segundo teléfono cargado, manda null', (
    tester,
  ) async {
    final repo = _EditRepository(account: lucia(phone2: '24001122'));
    await _pump(tester, repo);
    await _enter(tester, 'phone2', '');
    await _tapSave(tester);

    expect(repo.updates, [
      {'telefono2': null},
    ]);
  });

  testWidgets('muestra validaciones al guardar y al corregir campos', (
    tester,
  ) async {
    final repo = _EditRepository();
    await _pump(tester, repo);
    await _enter(tester, 'address', '');
    await _enter(tester, 'phone1', '123');
    await _enter(tester, 'phone2', '0' * 31);
    await _enter(tester, 'email', 'sin-arroba');
    expect(find.text('Ingresá tu dirección.'), findsNothing);
    await _tapSave(tester);

    expect(find.text('Ingresá tu dirección.'), findsOneWidget);
    expect(
      find.text(
        'Ese teléfono no parece válido. Revisá el número; si es de otro país, '
        'empezalo con + y el código de país.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('El teléfono no puede tener más de 30 caracteres.'),
      findsOneWidget,
    );
    expect(
      find.text('Ingresá un correo válido, por ejemplo nombre@ejemplo.org.'),
      findsOneWidget,
    );
    expect(repo.updates, isEmpty);

    await _enter(tester, 'address', 'Av. Italia 1234');
    await _enter(tester, 'phone1', '');
    await _enter(tester, 'phone2', '');
    await _enter(tester, 'email', '${'a' * 243}@example.org');
    expect(find.text('Ingresá tu dirección.'), findsNothing);
    expect(find.text('Ingresá un teléfono.'), findsOneWidget);
    expect(
      find.text('El teléfono no puede tener más de 30 caracteres.'),
      findsNothing,
    );
    expect(
      find.text('El correo no puede tener más de 254 caracteres.'),
      findsOneWidget,
    );
  });

  testWidgets('acepta ambos teléfonos de exactamente 30 caracteres', (
    tester,
  ) async {
    const phone = '0(9)-(9)-(1)-(2)-(3)-(4)(5)(6)';
    expect(phone.length, 30);
    final repo = _EditRepository();
    final router = await _pump(tester, repo);
    await _enter(tester, 'phone1', phone);
    await _enter(tester, 'phone2', phone);
    await _tapSave(tester);

    expect(repo.updates, [
      {'telefono1': phone, 'telefono2': phone},
    ]);
    expect(locationOf(router), kAccountPath);
  });

  testWidgets('muestra los cuatro errores juntos sin desborde a 320 px', (
    tester,
  ) async {
    final repo = _EditRepository();
    await _pump(tester, repo, size: const Size(320, 640));
    await _enter(tester, 'address', '');
    await _enter(tester, 'phone1', '123');
    await _enter(tester, 'phone2', '0' * 31);
    await _enter(tester, 'email', 'sin-arroba');
    await _tapSave(tester);

    expect(find.text('Ingresá tu dirección.'), findsOneWidget);
    expect(find.text(kInvalidPhoneMessage), findsOneWidget);
    expect(
      find.text('El teléfono no puede tener más de 30 caracteres.'),
      findsOneWidget,
    );
    expect(
      find.text('Ingresá un correo válido, por ejemplo nombre@ejemplo.org.'),
      findsOneWidget,
    );
    expect(repo.updates, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dos toques seguidos solo guardan una vez', (tester) async {
    final repo = _EditRepository()..saveGate = Completer<void>();
    await _pump(tester, repo);
    await _enter(tester, 'address', 'Av. Italia 1234');
    await tester.tap(_save);
    await tester.tap(_save);
    await tester.pump();

    expect(repo.updates, hasLength(1));
    expect(tester.widget<FilledButton>(_save).onPressed, isNull);
    repo.saveGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('si se vuelve durante el guardado, Mi cuenta usa la respuesta', (
    tester,
  ) async {
    final repo = _EditRepository(
      result: Account.fromJson({
        ...luciaJson(),
        'direccion': 'Av. Italia 1234',
      }),
    )..saveGate = Completer<void>();
    final router = await _pump(tester, repo);
    await _enter(tester, 'address', 'Av. Italia 1234');
    await _tapSave(tester);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(locationOf(router), '/cuenta');
    expect(
      textOf(tester, 'account-address'),
      'Av. 18 de Julio 1234, Montevideo',
    );
    repo.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(locationOf(router), '/cuenta');
    expect(textOf(tester, 'account-address'), 'Av. Italia 1234');
    expect(repo.calls, 1);
  });

  testWidgets('una ruta encima no se cierra al terminar el guardado', (
    tester,
  ) async {
    final repo = _EditRepository()..saveGate = Completer<void>();
    final router = await _pump(tester, repo);
    await _enter(tester, 'address', 'Av. Italia 1234');
    await _tapSave(tester);
    router.push('/encima');
    await tester.pumpAndSettle();

    expect(topOf(router), '/encima');
    expect(find.byType(EditAccountScreen, skipOffstage: false), findsOneWidget);
    repo.saveGate!.complete();
    await tester.pumpAndSettle();

    expect(repo.updates, hasLength(1));
    expect(topOf(router), '/encima');
    expect(_saved, findsNothing);
  });

  testWidgets('si el token se renueva al guardar, se publica la respuesta', (
    tester,
  ) async {
    final repo = _EditRepository(
      result: Account.fromJson({
        ...luciaJson(),
        'direccion': 'Av. Italia 1234',
      }),
    )..saveGate = Completer<void>();
    await _pump(tester, repo);
    final session = ProviderScope.containerOf(
      tester.element(find.byType(EditAccountScreen)),
      listen: false,
    ).read(sessionProvider.notifier);
    session.setAuthenticated(accessToken: 'original', role: UserRole.socio);
    await tester.pumpAndSettle();
    final readsBeforeSave = repo.calls;

    await _enter(tester, 'address', 'Av. Italia 1234');
    await _tapSave(tester);
    session.setAuthenticated(accessToken: 'renovado', role: UserRole.socio);
    await tester.pumpAndSettle();
    repo.saveGate!.complete();
    await tester.pumpAndSettle();

    expect(textOf(tester, 'account-address'), 'Av. Italia 1234');
    expect(repo.calls, readsBeforeSave);
  });

  testWidgets('avisa del correo nuevo y muestra el pendiente a 320 px', (
    tester,
  ) async {
    final repo = _EditRepository(
      result: lucia(pendingEmail: 'nuevo@example.org'),
    );
    await _pump(tester, repo, size: const Size(320, 640));
    await _enter(tester, 'email', ' nuevo@example.org ');
    await _tapSave(tester);

    expect(repo.updates, [
      {'correo': 'nuevo@example.org'},
    ]);
    expect(_saved, findsOneWidget);
    expect(find.text(_longNotice), findsOneWidget);
    expect(textOf(tester, 'account-email'), 'lucia@example.org');
    expect(find.byKey(const Key('account-pending-email')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un correo que ya estaba pendiente no repite el aviso largo', (
    tester,
  ) async {
    final repo = _EditRepository(
      account: lucia(pendingEmail: 'nuevo@example.org'),
      result: lucia(pendingEmail: 'nuevo@example.org'),
    );
    await _pump(tester, repo);
    await _enter(tester, 'address', 'Av. Italia 1234');
    await _tapSave(tester);
    expect(find.text(_shortNotice), findsOneWidget);
    expect(find.text(_longNotice), findsNothing);
  });

  testWidgets('un 400 muestra el mensaje y conserva el borrador a 320 px', (
    tester,
  ) async {
    const message =
        'No pudimos usar esa dirección. Revisá los datos ingresados y volvé a '
        'intentar para que podamos comunicarnos contigo.';
    final repo = _EditRepository(
      saveError: const AccountValidationException(message),
    );
    await _pump(tester, repo, size: const Size(320, 640));
    await _enter(tester, 'address', 'Av. Italia 1234');
    await _tapSave(tester);

    expect(textOf(tester, 'edit-error'), message);
    expect(_value(tester, 'address'), 'Av. Italia 1234');
    expect(tester.widget<FilledButton>(_save).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un error sin mensaje específico muestra el aviso de guardado', (
    tester,
  ) async {
    final repo = _EditRepository(saveError: const ApiException());
    await _pump(tester, repo);
    await _enter(tester, 'address', 'Av. Italia 1234');
    await _tapSave(tester);
    expect(
      textOf(tester, 'edit-error'),
      'No pudimos guardar tus datos. Intentá de nuevo.',
    );
  });

  testWidgets('si no carga los datos se puede reintentar', (tester) async {
    final repo = _EditRepository(error: const ApiException());
    await _pump(tester, repo);
    expect(
      find.text('No pudimos cargar tus datos. Intentá de nuevo.'),
      findsOneWidget,
    );
    expect(_field('address'), findsNothing);

    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(_value(tester, 'address'), 'Av. 18 de Julio 1234, Montevideo');
    expect(repo.calls, 2);
  });
}
