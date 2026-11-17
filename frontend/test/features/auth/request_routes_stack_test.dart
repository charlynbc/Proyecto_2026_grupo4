import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/features/auth/screens/first_login_request_screen.dart';
import 'package:agenda_medica/features/auth/screens/password_recovery_request_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'recovery_test_support.dart';

/// Pedir el enlace es una ruta hermana de la del enlace del correo, no hija:
/// si fuera hija, go_router apilaría debajo "Activá tu cuenta" o "Nueva
/// contraseña" (con el token vacío) y el atrás de Android las mostraría.
void main() {
  testWidgets('/primer-ingreso/solicitar tiene una sola página en la pila', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await goTo(tester, container, '/primer-ingreso/solicitar');

    expect(find.byType(FirstLoginRequestScreen), findsOneWidget);
    expect(container.read(goRouterProvider).canPop(), isFalse);
  });

  testWidgets('/recuperacion/solicitar tiene una sola página en la pila', (
    tester,
  ) async {
    final container = await pumpRecoveryApp(tester);
    await goTo(tester, container, '/recuperacion/solicitar');

    expect(find.byType(PasswordRecoveryRequestScreen), findsOneWidget);
    expect(container.read(goRouterProvider).canPop(), isFalse);
  });
}
