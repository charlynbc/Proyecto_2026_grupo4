import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:agenda_medica/features/turnos/screens/shifts_screen.dart';
import 'package:agenda_medica/features/turnos/screens/suspend_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

Future<void> _loginAs(
  WidgetTester tester,
  ProviderContainer container,
  UserRole role,
) async {
  final person = TestData.people.firstWhere((p) => p.role == role.apiValue);
  final repo = await container.read(authRepositoryProvider.future);
  final done = repo.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.forRole(role),
  );
  await tester.pumpAndSettle();
  await done;
  await tester.pumpAndSettle();
}

void main() {
  test('la ruta cuelga de la sección "Turnos" del funcionario', () {
    expect(kSuspendShiftsPath, '/funcionario/turnos/suspender');
    expect(kSuspendShiftsPath, startsWith('$kShiftsPath/'));
  });

  testWidgets('el funcionario llega a la ruta y ve la pantalla', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.funcionario);

    await goTo(tester, container, kSuspendShiftsPath);

    expect(locationOf(container), kSuspendShiftsPath);
    expect(find.byType(SuspendShiftsScreen), findsOneWidget);
    // Dentro del menú del funcionario, no en una página suelta.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Página no encontrada'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('socio, médico y administrador no llegan: van a su home', (
    tester,
  ) async {
    for (final role in [
      UserRole.socio,
      UserRole.medico,
      UserRole.administrador,
    ]) {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, role);

      await goTo(tester, container, kSuspendShiftsPath);

      expect(locationOf(container), role.homePath, reason: role.name);
      expect(find.byType(SuspendShiftsScreen), findsNothing, reason: role.name);
    }
    await unmountApp(tester);
  });

  testWidgets('sin sesión la ruta lleva al login', (tester) async {
    final container = await pumpApp(tester);

    await goTo(tester, container, kSuspendShiftsPath);

    expect(locationOf(container), '/login');
  });

  testWidgets(
    'desde la consulta de turnos, "Suspender fechas" abre la pantalla',
    (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.funcionario);
      expect(find.byType(ShiftsScreen), findsOneWidget);

      await tester.tap(find.text('Suspender fechas'));
      await tester.pumpAndSettle();

      expect(locationOf(container), kSuspendShiftsPath);
      expect(find.byType(SuspendShiftsScreen), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      await unmountApp(tester);
    },
  );
}
