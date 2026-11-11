import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/home/screens/home_screen.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/load_roboto.dart';

void main() {
  setUpAll(loadRoboto);
  final cases = {
    UserRole.funcionario: (
      '/funcionario/inicio',
      {
        'turnos': '/funcionario/turnos',
        'llegada': '/funcionario/llegada',
        'agendas': '/funcionario/agendas',
        'cartelera': '/funcionario/cartelera',
      },
    ),
    UserRole.medico: (
      '/medico/inicio',
      {
        'turnos': '/medico/turnos',
        'pases': '/medico/pases',
        'cartelera': '/medico/cartelera',
      },
    ),
    UserRole.administrador: (
      '/admin/inicio',
      {
        'usuarios': '/admin/usuarios',
        'especialidades': '/admin/especialidades',
        'consultorios': '/admin/consultorios',
        'estadisticas': '/admin/estadisticas',
        'cartelera': '/admin/cartelera',
      },
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key.name}: Inicio y navegacion angosta', (
      tester,
    ) async {
      final container = await pumpApp(tester, size: const Size(320, 800));
      final person = TestData.people.firstWhere(
        (p) => p.role == entry.key.apiValue,
      );
      final repo = await container.read(authRepositoryProvider.future);
      final login = repo.login(
        ci: person.ci,
        password: kTestPassword,
        access: AccessType.forRole(entry.key),
      );
      await tester.pumpAndSettle();
      await login;
      await tester.pumpAndSettle();
      expect(locationOf(container), entry.value.$1);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      for (final shortcut in entry.value.$2.entries) {
        await goTo(tester, container, entry.value.$1);
        final button = find.byKey(Key('home-shortcut-${shortcut.key}'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(locationOf(container), shortcut.value);
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(bar.destinations.length, entry.value.$2.length);
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Inicio'),
          ),
          findsNothing,
        );
      }
      for (var index = 0; index < entry.value.$2.length; index++) {
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        bar.onDestinationSelected!(index);
        await tester.pumpAndSettle();
        expect(locationOf(container), entry.value.$2.values.elementAt(index));
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index,
        );
      }
      await unmountApp(tester);
      if (entry.key == UserRole.medico) {
        container.invalidate(doctorAgendaControllerProvider);
      }
    });
  }
}
