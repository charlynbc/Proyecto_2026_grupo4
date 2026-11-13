import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:agenda_medica/features/cuenta/screens/account_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

/// Al cerrarse la sesión, el rol pasa a null y el repositorio falso se
/// vuelve a armar: el pedido que dispara tiene 300 ms de latencia y no
/// dibuja cuadros, así que pumpAndSettle no lo espera.
Future<void> _flushFakeLatency(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void main() {
  // La persona de prueba que tiene que mostrar /cuenta para cada rol,
  // escrita a mano.
  const expected = {
    UserRole.socio: ('12345672', 'Ana', 'Rodríguez'),
    UserRole.funcionario: ('23456783', 'Bruno', 'Pereira'),
    UserRole.medico: ('34567894', 'Carla', 'Méndez'),
    UserRole.administrador: ('45678905', 'Diego', 'Fernández'),
  };

  for (final entry in expected.entries) {
    testWidgets('con sesión de ${entry.key.apiValue}, /cuenta muestra sus '
        'datos', (tester) async {
      final container = await pumpAccountApp(tester);
      await loginAs(tester, container, entry.key);
      final router = appRouter(container);

      router.go(kAccountPath);
      await tester.pumpAndSettle();

      expect(locationOf(router), '/cuenta');
      final (ci, name, lastName) = entry.value;
      expect(textOf(tester, 'account-ci'), ci);
      expect(textOf(tester, 'account-name'), name);
      expect(textOf(tester, 'account-lastname'), lastName);
    });
  }

  testWidgets('el ícono de cuenta abre /cuenta y volver regresa a la pantalla '
      'del rol', (tester) async {
    final container = await pumpAccountApp(tester);
    await loginAs(tester, container, UserRole.socio);
    final router = appRouter(container);
    final home = locationOf(router);
    expect(home, '/socio/inicio');

    await tester.tap(find.byKey(const Key('open-account')));
    await tester.pumpAndSettle();
    expect(topOf(router), '/cuenta');
    expect(textOf(tester, 'account-ci'), '12345672');

    await tester.tap(find.byKey(const Key('account-back')));
    await tester.pumpAndSettle();
    expect(topOf(router), home);
    expect(find.byType(AccountScreen), findsNothing);
  });

  testWidgets('entrando directo a /cuenta, la flecha lleva al inicio del rol', (
    tester,
  ) async {
    final container = await pumpAccountApp(tester);
    await loginAs(tester, container, UserRole.funcionario);
    final router = appRouter(container);
    router.go(kAccountPath);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account-back')));
    await tester.pumpAndSettle();

    expect(locationOf(router), '/funcionario/inicio');
  });

  testWidgets('si la sesión se cae estando en /cuenta, va al login', (
    tester,
  ) async {
    final container = await pumpAccountApp(tester);
    await loginAs(tester, container, UserRole.socio);
    final router = appRouter(container);
    router.go(kAccountPath);
    await tester.pumpAndSettle();
    expect(find.byType(AccountScreen), findsOneWidget);

    container.read(sessionProvider.notifier).clear(expired: true);
    await tester.pumpAndSettle();

    expect(locationOf(router), '/login');
    expect(find.byType(AccountScreen), findsNothing);
    await _flushFakeLatency(tester);
  });

  testWidgets('si la sesión se cae con Mi cuenta abierta desde el ícono, va '
      'al login', (tester) async {
    final container = await pumpAccountApp(tester);
    await loginAs(tester, container, UserRole.medico);
    final router = appRouter(container);
    await tester.tap(find.byKey(const Key('open-account')));
    await tester.pumpAndSettle();
    expect(topOf(router), '/cuenta');

    container.read(sessionProvider.notifier).clear(expired: true);
    await tester.pumpAndSettle();

    expect(locationOf(router), '/login');
    expect(topOf(router), '/login');
    expect(find.byType(AccountScreen), findsNothing);
    await _flushFakeLatency(tester);
  });

  testWidgets('sin sesión /cuenta va al login', (tester) async {
    final container = await pumpAccountApp(tester);
    final router = appRouter(container);

    router.go(kAccountPath);
    await tester.pumpAndSettle();

    expect(locationOf(router), startsWith('/login'));
  });
}
