import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/screens/confirm_email_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'email_change_test_support.dart';

void main() {
  testWidgets('sin sesión, /cambio-correo?token=abc se queda y la pantalla '
      'recibe abc', (tester) async {
    final container = await pumpEmailChangeApp(tester);

    await goTo(tester, container, '/cambio-correo?token=abc');

    expect(locationOf(container), '/cambio-correo?token=abc');
    final screen = tester.widget<ConfirmEmailChangeScreen>(
      find.byType(ConfirmEmailChangeScreen),
    );
    expect(screen.token, 'abc');
  });

  testWidgets('con sesión de cada rol, el enlace no lo saca de ahí', (
    tester,
  ) async {
    for (final role in UserRole.values) {
      final container = await pumpEmailChangeApp(tester);
      await loginAs(tester, container, role);
      expect(locationOf(container), role.homePath, reason: role.name);

      await goTo(tester, container, '/cambio-correo?token=abc');

      expect(
        locationOf(container),
        '/cambio-correo?token=abc',
        reason: role.name,
      );
      expect(find.byType(ConfirmEmailChangeScreen), findsOneWidget);
      await unmountApp(tester);
    }
  });

  testWidgets('con sesión, "Ir al inicio" después de confirmar lleva al '
      'inicio del rol', (tester) async {
    final container = await pumpEmailChangeApp(tester);
    await loginAs(tester, container, UserRole.socio);
    await goTo(tester, container, '/cambio-correo?token=abc');

    await tester.tap(find.byKey(const Key('email-change-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('email-change-home')));
    await tester.pumpAndSettle();

    expect(locationOf(container), UserRole.socio.homePath);
    await unmountApp(tester);
  });

  testWidgets('sin token o con el token vacío no se queda en la pantalla', (
    tester,
  ) async {
    final container = await pumpEmailChangeApp(tester);

    await goTo(tester, container, '/cambio-correo');
    expect(find.byType(ConfirmEmailChangeScreen), findsNothing);
    // "/" sin sesión termina en el login.
    expect(locationOf(container), '/login');

    await goTo(tester, container, '/cambio-correo?token=');
    expect(find.byType(ConfirmEmailChangeScreen), findsNothing);
    expect(locationOf(container), '/login');
  });
}
