import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

void main() {
  for (final role in UserRole.values) {
    testWidgets('${role.name} puede editar su cuenta y ver el cambio', (
      tester,
    ) async {
      final container = await pumpAccountApp(
        tester,
        size: const Size(360, 800),
      );
      await loginAs(tester, container, role);
      final router = appRouter(container);
      router.go('/cuenta');
      await tester.pumpAndSettle();

      final ci = textOf(tester, 'account-ci');
      final edit = find.byKey(const Key('account-edit'));
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(topOf(router), '/cuenta/editar');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Editar mis datos'), findsOneWidget);

      const fields = {
        'edit-address': 'Av. Italia 1234',
        'edit-phone1': '099876543',
        'edit-phone2': '24001234',
        'edit-email': 'nuevo@example.org',
      };
      for (final field in fields.entries) {
        final finder = find.byKey(Key(field.key));
        await tester.ensureVisible(finder);
        await tester.enterText(finder, field.value);
      }
      await tester.pump();
      final save = find.byKey(const Key('edit-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(topOf(router), '/cuenta');
      expect(textOf(tester, 'account-address'), 'Av. Italia 1234');
      expect(textOf(tester, 'account-phone1'), '099876543');
      expect(textOf(tester, 'account-phone2'), '24001234');
      expect(textOf(tester, 'account-ci'), ci);
      expect(
        textOf(tester, 'account-pending-email'),
        contains('Pediste cambiar tu correo a nuevo@example.org.'),
      );
      expect(find.byKey(const Key('edit-saved')), findsOneWidget);
    });
  }

  testWidgets('si se abre la ruta directamente, la flecha va a Mi cuenta', (
    tester,
  ) async {
    final container = await pumpAccountApp(tester);
    await loginAs(tester, container, UserRole.socio);
    final router = appRouter(container);
    router.go('/cuenta/editar');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(topOf(router), '/cuenta');
  });
}
