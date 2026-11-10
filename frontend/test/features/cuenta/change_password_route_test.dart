import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/screens/account_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

void main() {
  for (final role in UserRole.values) {
    testWidgets('${role.apiValue} abre el formulario y puede volver', (
      tester,
    ) async {
      final container = await pumpAccountApp(tester);
      await loginAs(tester, container, role);
      final router = appRouter(container);
      router.go(kAccountPath);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-password')));
      await tester.pumpAndSettle();
      expect(topOf(router), kAccountPasswordPath);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(topOf(router), kAccountPath);
    });
  }

  testWidgets('sin sesión la ruta lleva al login', (tester) async {
    final container = await pumpAccountApp(tester);
    final router = appRouter(container);
    router.go(kAccountPasswordPath);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');
  });
}
