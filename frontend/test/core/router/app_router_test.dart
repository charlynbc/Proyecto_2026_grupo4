import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/app_router.dart';
import 'package:agenda_medica/core/router/app_sections.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:agenda_medica/features/auth/providers/session_provider.dart';
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
  group('redirectFor', () {
    const checking = SessionState(status: SessionStatus.checking);
    const anonymous = SessionState();
    const socio = SessionState(
      status: SessionStatus.authenticated,
      accessToken: 't',
      role: UserRole.socio,
    );

    test('verificando la sesión conserva el enlace de primer ingreso', () {
      expect(redirectFor(checking, Uri.parse('/primer-ingreso?token=x')), null);
      expect(redirectFor(checking, Uri.parse('/login')), '/');
      expect(redirectFor(checking, Uri.parse('/socio/consultas')), '/');
    });

    test('sin sesión solo se entra a login y primer ingreso', () {
      expect(redirectFor(anonymous, Uri.parse('/login')), null);
      expect(redirectFor(anonymous, Uri.parse('/admin/usuarios')), '/login');
      expect(
        redirectFor(anonymous, Uri.parse('/primer-ingreso')),
        '/primer-ingreso/solicitar',
      );
      expect(
        redirectFor(anonymous, Uri.parse('/primer-ingreso?token=abc')),
        null,
      );
    });

    test('con sesión no se vuelve al login ni a otro rol', () {
      expect(redirectFor(socio, Uri.parse('/login')), UserRole.socio.homePath);
      expect(
        redirectFor(socio, Uri.parse('/primer-ingreso?token=x')),
        UserRole.socio.homePath,
      );
      expect(
        redirectFor(socio, Uri.parse('/medico/turnos')),
        UserRole.socio.homePath,
      );
      expect(redirectFor(socio, Uri.parse('/socio')), UserRole.socio.homePath);
      expect(redirectFor(socio, Uri.parse('/socio/historia')), null);
    });
  });

  testWidgets('cada rol entra a su home y ve solo sus secciones', (
    tester,
  ) async {
    for (final role in UserRole.values) {
      final container = await pumpApp(tester);
      expect(locationOf(container), '/login');

      await _loginAs(tester, container, role);

      expect(locationOf(container), role.homePath, reason: role.name);
      final labels = role.sections.map((s) => s.label).toSet();
      if (role.sections.length > 1) {
        for (final label in labels) {
          expect(find.text(label), findsWidgets, reason: '${role.name}/$label');
        }
      }
      // Ninguna sección de otro rol.
      for (final other in UserRole.values.where((r) => r != role)) {
        for (final section in other.sections) {
          if (labels.contains(section.label)) continue;
          expect(find.text(section.label), findsNothing);
        }
      }
      // Lo que no existe todavía va a "Próximamente".
      expect(find.text('Próximamente'), findsOneWidget);
    }
  });

  testWidgets(
    'el médico, con una sola sección, no muestra barra de navegación',
    (tester) async {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, UserRole.medico);

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
    },
  );

  testWidgets('un rol no puede entrar a las rutas de otro', (tester) async {
    for (final role in UserRole.values) {
      final container = await pumpApp(tester);
      await _loginAs(tester, container, role);

      for (final other in UserRole.values.where((r) => r != role)) {
        for (final section in other.sections) {
          await goTo(tester, container, other.sectionPath(section));
          expect(
            locationOf(container),
            role.homePath,
            reason: '${role.name} → ${other.sectionPath(section)}',
          );
        }
        await goTo(tester, container, other.routePrefix);
        expect(locationOf(container), role.homePath);
      }

      // Sus propias secciones sí.
      final last = role.sections.last;
      await goTo(tester, container, role.sectionPath(last));
      expect(locationOf(container), role.sectionPath(last));
    }
  });

  testWidgets('sin sesión, una ruta de un rol lleva al login', (tester) async {
    final container = await pumpApp(tester);

    await goTo(tester, container, '/admin/usuarios');

    expect(locationOf(container), '/login');
  });

  testWidgets('al cerrar la sesión se vuelve al login', (tester) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.socio);

    container.read(sessionProvider.notifier).clear();
    await tester.pumpAndSettle();

    expect(locationOf(container), '/login');
  });

  testWidgets('una sesión caída lleva al login con un aviso comprensible', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    await _loginAs(tester, container, UserRole.funcionario);

    container.read(sessionProvider.notifier).clear(expired: true);
    await tester.pumpAndSettle();

    expect(locationOf(container), '/login');
    expect(find.text('Tu sesión se cerró'), findsOneWidget);
    expect(
      find.textContaining('comunicate con la institución'),
      findsOneWidget,
    );
  });
}
