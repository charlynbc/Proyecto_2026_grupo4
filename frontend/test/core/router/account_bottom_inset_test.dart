import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/system_inset_support.dart';

/// "Mi cuenta" es una ruta de nivel superior: se ve sin barra inferior propia.
void main() {
  const lastElement = Key('account-password');

  testWidgets(
    'angosto: "Cambiar contraseña" queda sobre la barra del sistema',
    (tester) async {
      final container = await pumpAsWithInset(
        tester,
        UserRole.socio,
        size: kNarrowPhone,
        bottom: kSystemNavigationBar,
      );
      await goTo(tester, container, kAccountPath);

      await scrollToEnd(tester);

      final bottom = bottomOf(tester, find.byKey(lastElement));
      expect(bottom, lessThanOrEqualTo(600 - 48));
      // 552 dp de alto útil menos los 32 dp de padding vertical del contenido.
      expect(bottom, closeTo(520, 0.01));
    },
  );

  testWidgets('ancho: "Cambiar contraseña" queda sobre la barra del sistema', (
    tester,
  ) async {
    final container = await pumpAsWithInset(
      tester,
      UserRole.socio,
      size: kWidePhone,
      bottom: kSystemNavigationBar,
    );
    await goTo(tester, container, kAccountPath);

    await scrollToEnd(tester);

    expect(
      bottomOf(tester, find.byKey(lastElement)),
      lessThanOrEqualTo(600 - 48),
    );
  });

  testWidgets('con padding inferior 0 el layout es el de siempre', (
    tester,
  ) async {
    final container = await pumpAsWithInset(
      tester,
      UserRole.socio,
      size: kNarrowPhone,
      bottom: 0,
    );
    await goTo(tester, container, kAccountPath);

    await scrollToEnd(tester);

    // 600 dp de alto menos los 32 dp de padding vertical del contenido.
    expect(bottomOf(tester, find.byKey(lastElement)), closeTo(568, 0.01));
  });
}
