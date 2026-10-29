import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/core/widgets/coming_soon_screen.dart';
import 'package:agenda_medica/features/agendas/screens/schedule_routes.dart';
import 'package:agenda_medica/features/agendas/screens/schedules_screen.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
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

/// Desmonta la app y suelta el container. La pantalla de agendas tiene un
/// temporizador periódico (el refresco de 15 s): al sacar el árbol entero,
/// Riverpod no llega a liberarlo con el reloj falso, y el test fallaría por un
/// `Timer` pendiente. `pumpApp` vuelve a soltar el container al terminar, y
/// hacerlo dos veces no molesta.
Future<void> _unmountAndRelease(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await unmountApp(tester);
  container.dispose();
}

void main() {
  test('la ruta cuelga de la sección "Agendas" del funcionario', () {
    final section = UserRole.funcionario.sections.firstWhere(
      (s) => s.slug == 'agendas',
    );

    expect(kSchedulesPath, '/funcionario/agendas');
    expect(UserRole.funcionario.sectionPath(section), kSchedulesPath);
  });

  testWidgets('el funcionario en /funcionario/agendas ve la pantalla de '
      'agendas y no "Próximamente"', (tester) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.funcionario);

    await goTo(tester, container, kSchedulesPath);

    expect(locationOf(container), kSchedulesPath);
    expect(find.byType(SchedulesScreen), findsOneWidget);
    expect(find.byType(ComingSoonScreen), findsNothing);
    expect(find.text('Próximamente'), findsNothing);
    // Sigue dentro del menú del funcionario.
    expect(find.byType(NavigationRail), findsOneWidget);
    await _unmountAndRelease(tester, container);
  });

  testWidgets('la sección "Agendas" del menú abre la pantalla de agendas', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.funcionario);

    await tester.tap(find.text('Agendas'));
    await tester.pumpAndSettle();

    expect(locationOf(container), kSchedulesPath);
    expect(find.byType(SchedulesScreen), findsOneWidget);
    await _unmountAndRelease(tester, container);
  });

  testWidgets('socio, médico y administrador no entran: van a su home', (
    tester,
  ) async {
    for (final role in [
      UserRole.socio,
      UserRole.medico,
      UserRole.administrador,
    ]) {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, role);

      await goTo(tester, container, kSchedulesPath);

      expect(locationOf(container), role.homePath, reason: role.name);
      expect(find.byType(SchedulesScreen), findsNothing, reason: role.name);
    }
    await unmountApp(tester);
  });

  testWidgets('sin sesión la ruta lleva al login', (tester) async {
    final container = await pumpApp(tester);

    await goTo(tester, container, kSchedulesPath);

    expect(locationOf(container), '/login');
    expect(find.byType(SchedulesScreen), findsNothing);
  });
}
