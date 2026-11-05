import 'package:agenda_medica/features/auth/screens/password_recovery_complete_screen.dart';
import 'package:agenda_medica/features/auth/screens/password_recovery_request_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'recovery_test_support.dart';

const _recoveredMessage =
    'Tu contraseña se actualizó correctamente. Ya podés iniciar sesión.';

Finder get _forgot => find.byKey(const Key('login-forgot-password'));

void main() {
  group('login', () {
    testWidgets('"Olvidé mi contraseña" desde el acceso de socios lleva a '
        'pedir el enlace con acceso=socio', (tester) async {
      final container = await pumpRecoveryApp(tester);
      expect(locationOf(container), '/login');

      expect(find.text('Olvidé mi contraseña'), findsOneWidget);
      await tester.tap(_forgot);
      await tester.pumpAndSettle();

      expect(locationOf(container), '/recuperacion/solicitar?acceso=socio');
      expect(find.byType(PasswordRecoveryRequestScreen), findsOneWidget);
    });

    testWidgets('desde el acceso de empleados lleva con acceso=empleado', (
      tester,
    ) async {
      final container = await pumpRecoveryApp(tester);

      await tester.tap(find.text('Ingresar por el acceso de empleados'));
      await tester.pumpAndSettle();
      await tester.tap(_forgot);
      await tester.pumpAndSettle();

      expect(locationOf(container), '/recuperacion/solicitar?acceso=empleado');
    });

    testWidgets('/login?recuperada=1 muestra el aviso y /login solo no', (
      tester,
    ) async {
      final container = await pumpRecoveryApp(tester);
      expect(find.text(_recoveredMessage), findsNothing);

      await goTo(tester, container, '/login?recuperada=1');
      expect(find.text(_recoveredMessage), findsOneWidget);

      await goTo(tester, container, '/login');
      expect(find.text(_recoveredMessage), findsNothing);
    });

    testWidgets('"Olvidé mi contraseña" se apaga mientras el login carga y '
        'vuelve a funcionar al terminar', (tester) async {
      final auth = GatedAuthRepository();
      await pumpRecoveryApp(tester, auth: auth);
      bool enabled() => tester.widget<TextButton>(_forgot).onPressed != null;
      expect(enabled(), isTrue);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '12345672');
      await tester.enterText(fields.at(1), 'prueba1234');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pump();

      expect(enabled(), isFalse);

      auth.gate.complete();
      await tester.pumpAndSettle();
      expect(enabled(), isTrue);
    });
  });

  group('enlace del correo, sin sesión', () {
    testWidgets('/recuperacion?token=abc se queda en esa ruta y la pantalla '
        'recibe abc', (tester) async {
      final container = await pumpRecoveryApp(tester);

      await goTo(tester, container, '/recuperacion?token=abc');

      expect(locationOf(container), '/recuperacion?token=abc');
      final screen = tester.widget<PasswordRecoveryCompleteScreen>(
        find.byType(PasswordRecoveryCompleteScreen),
      );
      expect(screen.token, 'abc');
    });

    testWidgets('/recuperacion sin token va a pedir el enlace', (tester) async {
      final container = await pumpRecoveryApp(tester);

      await goTo(tester, container, '/recuperacion');

      expect(locationOf(container), '/recuperacion/solicitar');
    });

    testWidgets('/recuperacion?token= (vacío) va a pedir el enlace', (
      tester,
    ) async {
      final container = await pumpRecoveryApp(tester);

      await goTo(tester, container, '/recuperacion?token=');

      expect(locationOf(container), '/recuperacion/solicitar');
    });
  });
}
