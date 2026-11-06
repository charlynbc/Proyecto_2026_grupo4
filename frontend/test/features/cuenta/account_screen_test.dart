import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:agenda_medica/features/cuenta/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import 'account_test_support.dart';

const _pendingNotice =
    'Pediste cambiar tu correo a nuevo@example.org. Abrí el enlace que te '
    'enviamos a ese correo para confirmarlo. Hasta entonces seguís usando '
    'lucia@example.org.';
const _loadError = 'No pudimos cargar tus datos. Intentá de nuevo.';

/// Un inicio en `/`, una pantalla anterior que abre la cuenta con `push`, y
/// la cuenta.
final _routes = <RouteBase>[
  GoRoute(
    path: '/',
    builder: (_, _) => const Scaffold(body: Text('Inicio')),
  ),
  GoRoute(
    path: '/anterior',
    builder: (context, _) => Scaffold(
      body: TextButton(
        onPressed: () => context.push(kAccountPath),
        child: const Text('Abrir cuenta'),
      ),
    ),
  ),
  GoRoute(path: kAccountPath, builder: (_, _) => const AccountScreen()),
];

Future<GoRouter> _pump(
  WidgetTester tester,
  RecordingAccountRepository repo, {
  String initialLocation = kAccountPath,
  Size size = const Size(900, 1800),
}) => pumpAdminScreens(
  tester,
  routes: _routes,
  initialLocation: initialLocation,
  overrides: [accountRepositoryProvider.overrideWith((ref) async => repo)],
  size: size,
);

void main() {
  setUpAll(loadRoboto);

  testWidgets('muestra los datos de la cuenta con sus valores', (tester) async {
    await _pump(tester, RecordingAccountRepository());

    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Datos de la cuenta'), findsOneWidget);
    expect(find.text('Datos de contacto'), findsOneWidget);
    expect(textOf(tester, 'account-ci'), '45678911');
    expect(textOf(tester, 'account-name'), 'Lucía');
    expect(textOf(tester, 'account-lastname'), 'Fernández');
    expect(textOf(tester, 'account-role'), 'Socio');
    expect(textOf(tester, 'account-email'), 'lucia@example.org');
    expect(textOf(tester, 'account-phone1'), '099123456');
    expect(textOf(tester, 'account-phone2'), 'No cargado');
    expect(
      textOf(tester, 'account-address'),
      'Av. 18 de Julio 1234, Montevideo',
    );
  });

  testWidgets('el teléfono 2 cargado se muestra', (tester) async {
    await _pump(
      tester,
      RecordingAccountRepository(account: lucia(phone2: '24001122')),
    );

    expect(textOf(tester, 'account-phone2'), '24001122');
  });

  const roleLabels = {
    UserRole.socio: 'Socio',
    UserRole.funcionario: 'Funcionario',
    UserRole.medico: 'Médico',
    UserRole.administrador: 'Administrador',
  };
  for (final entry in roleLabels.entries) {
    testWidgets('el rol ${entry.key.apiValue} se muestra "${entry.value}"', (
      tester,
    ) async {
      await _pump(
        tester,
        RecordingAccountRepository(account: lucia(role: entry.key)),
      );

      expect(textOf(tester, 'account-role'), entry.value);
    });
  }

  testWidgets('con correo pendiente avisa con los dos correos', (tester) async {
    await _pump(
      tester,
      RecordingAccountRepository(
        account: lucia(pendingEmail: 'nuevo@example.org'),
      ),
    );

    expect(textOf(tester, 'account-pending-email'), _pendingNotice);
  });

  testWidgets('sin correo pendiente no hay aviso', (tester) async {
    await _pump(tester, RecordingAccountRepository());

    expect(find.byKey(const Key('account-pending-email')), findsNothing);
  });

  testWidgets('los dos botones existen y están apagados', (tester) async {
    await _pump(tester, RecordingAccountRepository());

    final edit = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('account-edit')),
    );
    final password = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('account-password')),
    );
    expect(find.text('Editar mis datos'), findsOneWidget);
    expect(find.text('Cambiar contraseña'), findsOneWidget);
    expect(edit.onPressed, isNull);
    expect(password.onPressed, isNull);
  });

  testWidgets('mientras carga muestra un indicador', (tester) async {
    // A mano y sin pumpAndSettle: el indicador gira y nunca se asienta.
    final repo = RecordingAccountRepository()..gate = Completer<void>();
    final router = GoRouter(initialLocation: kAccountPath, routes: _routes);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountRepositoryProvider.overrideWith((ref) async => repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('account-ci')), findsNothing);

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(textOf(tester, 'account-ci'), '45678911');
  });

  testWidgets('si falla avisa y Reintentar vuelve a pedir', (tester) async {
    final repo = RecordingAccountRepository(error: const ApiException());
    await _pump(tester, repo);

    expect(find.text(_loadError), findsOneWidget);
    expect(find.byKey(const Key('account-ci')), findsNothing);
    expect(repo.calls, 1);

    repo.error = null;
    await tester.tap(find.byKey(const Key('account-retry')));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.text(_loadError), findsNothing);
    expect(textOf(tester, 'account-ci'), '45678911');
  });

  testWidgets('la flecha vuelve a la pantalla anterior', (tester) async {
    final router = await _pump(
      tester,
      RecordingAccountRepository(),
      initialLocation: '/anterior',
    );
    await tester.tap(find.text('Abrir cuenta'));
    await tester.pumpAndSettle();
    expect(topOf(router), '/cuenta');
    expect(find.byType(AccountScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-back')));
    await tester.pumpAndSettle();

    expect(topOf(router), '/anterior');
    expect(find.byType(AccountScreen), findsNothing);
    expect(find.text('Abrir cuenta'), findsOneWidget);
  });

  testWidgets('sin historial (recarga en /cuenta) la flecha lleva a /', (
    tester,
  ) async {
    final router = await _pump(tester, RecordingAccountRepository());

    await tester.tap(find.byKey(const Key('account-back')));
    await tester.pumpAndSettle();

    expect(currentLocation(router), '/');
  });

  group('a 320 px con Roboto', () {
    const size = Size(320, 640);

    testWidgets('los datos no desbordan', (tester) async {
      await _pump(tester, RecordingAccountRepository(), size: size);

      expect(textOf(tester, 'account-ci'), '45678911');
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error no desborda', (tester) async {
      await _pump(
        tester,
        RecordingAccountRepository(error: const ApiException()),
        size: size,
      );

      expect(find.text(_loadError), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el correo pendiente no desborda', (tester) async {
      await _pump(
        tester,
        RecordingAccountRepository(
          account: lucia(pendingEmail: 'nuevo@example.org'),
        ),
        size: size,
      );

      expect(textOf(tester, 'account-pending-email'), _pendingNotice);
      expect(tester.takeException(), isNull);
    });
  });
}
