import 'package:agenda_medica/features/auth/screens/first_login_activation_screen.dart';
import 'package:agenda_medica/features/auth/screens/login_screen.dart';
import 'package:agenda_medica/features/auth/screens/password_recovery_complete_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'recovery_test_support.dart';

/// Cuántas veces la app le pidió al sistema que se cierre (`SystemNavigator.pop`
/// es lo que hace el atrás de Android cuando ninguna pantalla lo atiende).
int _exits = 0;

void _watchExits(WidgetTester tester) {
  _exits = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.pop') _exits++;
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

/// El botón de atrás de Android.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('desde el ingreso a pedir el enlace', () {
    for (final access in const ['socio', 'empleado']) {
      Future<void> chooseAccess(WidgetTester tester) async {
        if (access == 'empleado') {
          await tester.tap(find.text('Ingresar por el acceso de empleados'));
          await tester.pumpAndSettle();
        }
      }

      testWidgets('"Es mi primera vez" y atrás vuelve al ingreso de $access', (
        tester,
      ) async {
        _watchExits(tester);
        final container = await pumpApp(tester);
        await chooseAccess(tester);
        await tester.tap(find.text('Es mi primera vez'));
        await tester.pumpAndSettle();
        expect(
          locationOf(container),
          '/primer-ingreso/solicitar?acceso=$access',
        );

        await _systemBack(tester);

        expect(locationOf(container), '/login?acceso=$access');
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(FirstLoginActivationScreen), findsNothing);
        expect(_exits, 0);
      });

      testWidgets('"Olvidé mi contraseña" y atrás vuelve al ingreso de '
          '$access', (tester) async {
        _watchExits(tester);
        final container = await pumpRecoveryApp(tester);
        await chooseAccess(tester);
        await tester.tap(find.text('Olvidé mi contraseña'));
        await tester.pumpAndSettle();
        expect(locationOf(container), '/recuperacion/solicitar?acceso=$access');

        await _systemBack(tester);

        expect(locationOf(container), '/login?acceso=$access');
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(PasswordRecoveryCompleteScreen), findsNothing);
        expect(_exits, 0);
      });
    }
  });

  group('atrás en las pantallas de pedir el enlace', () {
    testWidgets('Primer ingreso conserva el acceso de empleados', (
      tester,
    ) async {
      _watchExits(tester);
      final container = await pumpApp(tester);
      await goTo(
        tester,
        container,
        '/primer-ingreso/solicitar?acceso=empleado',
      );

      await _systemBack(tester);

      expect(locationOf(container), '/login?acceso=empleado');
      expect(_exits, 0);
    });

    testWidgets('Recuperar contraseña conserva el acceso de empleados', (
      tester,
    ) async {
      _watchExits(tester);
      final container = await pumpRecoveryApp(tester);
      await goTo(tester, container, '/recuperacion/solicitar?acceso=empleado');

      await _systemBack(tester);

      expect(locationOf(container), '/login?acceso=empleado');
      expect(_exits, 0);
    });

    testWidgets('desde "Revisá tu correo" también vuelve al ingreso', (
      tester,
    ) async {
      _watchExits(tester);
      final container = await pumpApp(tester);
      await goTo(tester, container, '/primer-ingreso/solicitar');
      await tester.enterText(find.byType(TextFormField), '12345672');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Revisá tu correo'), findsOneWidget);

      await _systemBack(tester);

      expect(locationOf(container), '/login?acceso=socio');
      expect(_exits, 0);
    });
  });

  group('atrás en las pantallas del enlace del correo', () {
    testWidgets('Activá tu cuenta con token vuelve al ingreso', (tester) async {
      _watchExits(tester);
      final container = await pumpApp(tester);
      await goTo(tester, container, '/primer-ingreso?token=abc123');
      expect(find.byType(FirstLoginActivationScreen), findsOneWidget);

      await _systemBack(tester);

      expect(locationOf(container), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_exits, 0);
    });

    testWidgets('Nueva contraseña con token vuelve al ingreso', (tester) async {
      _watchExits(tester);
      final container = await pumpRecoveryApp(tester);
      await goTo(tester, container, '/recuperacion?token=abc123');
      expect(find.byType(PasswordRecoveryCompleteScreen), findsOneWidget);

      await _systemBack(tester);

      expect(locationOf(container), '/login');
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(_exits, 0);
    });
  });

  group('atrás en el ingreso', () {
    testWidgets('no se intercepta: cierra la app', (tester) async {
      _watchExits(tester);
      final container = await pumpApp(tester);
      expect(locationOf(container), '/login');

      await _systemBack(tester);

      expect(_exits, 1);
      expect(locationOf(container), '/login');
    });
  });
}
