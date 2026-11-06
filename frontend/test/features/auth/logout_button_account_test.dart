import 'package:agenda_medica/features/auth/widgets/logout_button.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:agenda_medica/features/cuenta/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';
import '../cuenta/account_test_support.dart';

/// Una pantalla con el botón en el AppBar, como las 13 que lo usan.
final _routes = <RouteBase>[
  GoRoute(
    path: '/',
    builder: (_, _) => const Scaffold(body: Text('Inicio')),
  ),
  GoRoute(
    path: '/pantalla',
    builder: (_, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Pantalla'),
        actions: const [LogoutButton()],
      ),
    ),
  ),
  GoRoute(path: kAccountPath, builder: (_, _) => const AccountScreen()),
];

Future<GoRouter> _pump(WidgetTester tester) => pumpAdminScreens(
  tester,
  routes: _routes,
  initialLocation: '/pantalla',
  overrides: [
    accountRepositoryProvider.overrideWith(
      (ref) async => RecordingAccountRepository(),
    ),
  ],
);

void main() {
  testWidgets('muestra "Mi cuenta" antes de "Cerrar sesión"', (tester) async {
    await _pump(tester);

    final account = find.byTooltip('Mi cuenta');
    final logout = find.byTooltip('Cerrar sesión');
    expect(account, findsOneWidget);
    expect(logout, findsOneWidget);
    expect(find.byKey(const Key('open-account')), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(tester.getCenter(account).dx, lessThan(tester.getCenter(logout).dx));
  });

  testWidgets('"Mi cuenta" abre /cuenta y volver regresa a la pantalla', (
    tester,
  ) async {
    final router = await _pump(tester);

    await tester.tap(find.byKey(const Key('open-account')));
    await tester.pumpAndSettle();
    expect(topOf(router), kAccountPath);
    expect(textOf(tester, 'account-ci'), '45678911');

    await tester.tap(find.byKey(const Key('account-back')));
    await tester.pumpAndSettle();
    expect(topOf(router), '/pantalla');
    expect(find.byType(AccountScreen), findsNothing);
    expect(find.text('Pantalla'), findsOneWidget);
  });

  testWidgets('"Cerrar sesión" abre el diálogo de siempre', (tester) async {
    final router = await _pump(tester);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('¿Confirmás que querés cerrar la sesión?'),
      findsOneWidget,
    );
    expect(find.text('Cancelar'), findsOneWidget);
    expect(currentLocation(router), '/pantalla');

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(currentLocation(router), '/pantalla');
  });
}
