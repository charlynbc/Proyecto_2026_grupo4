import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';

Future<void> _loginAs(
  WidgetTester tester,
  ProviderContainer container,
  UserRole role,
) async {
  final person = TestData.people.firstWhere((p) => p.role == role.apiValue);
  final repository = await container.read(authRepositoryProvider.future);
  final done = repository.login(
    ci: person.ci,
    password: kTestPassword,
    access: AccessType.forRole(role),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
  await done;
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

double _labelHeight(WidgetTester tester, String label) {
  final text = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == label,
    ),
  );
  expect(text, findsOneWidget, reason: label);
  expect(text.hitTestable(), findsOneWidget, reason: '$label debe ser visible');
  final height = tester.getSize(text).height;
  expect(height, greaterThan(0), reason: label);
  return height;
}

void _expectNarrowShell(WidgetTester tester) {
  expect(find.byType(NavigationBar), findsOneWidget);
  expect(find.byType(NavigationRail), findsNothing);
  expect(tester.getSize(find.byType(NavigationBar)).width, 320);
  expect(tester.view.physicalSize, const Size(320, 800));
  expect(tester.view.devicePixelRatio, 1);
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);

  testWidgets('administrador a 320 px mantiene las etiquetas en una línea', (
    tester,
  ) async {
    final container = await pumpApp(tester, size: const Size(320, 800));
    try {
      await _loginAs(tester, container, UserRole.administrador);
      _expectNarrowShell(tester);

      final usuarios = _labelHeight(tester, 'Usuarios');
      final especialidades = _labelHeight(tester, 'Especialidades');
      final consultorios = _labelHeight(tester, 'Consultorios');
      final estadisticas = _labelHeight(tester, 'Estadísticas');

      expect(
        especialidades,
        closeTo(usuarios, 0.01),
        reason: 'Especialidades debe ocupar una línea, igual que Usuarios',
      );
      expect(
        consultorios,
        closeTo(usuarios, 0.01),
        reason: 'Consultorios debe ocupar una línea, igual que Usuarios',
      );
      expect(
        estadisticas,
        closeTo(usuarios, 0.01),
        reason: 'Estadísticas debe ocupar una línea, igual que Usuarios',
      );
      expect(tester.takeException(), isNull);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('socio a 320 px no parte palabras y admite hasta dos líneas', (
    tester,
  ) async {
    final container = await pumpApp(tester, size: const Size(320, 800));
    try {
      await _loginAs(tester, container, UserRole.socio);
      _expectNarrowShell(tester);

      final cartelera = _labelHeight(tester, 'Cartelera');
      final disponibilidad = _labelHeight(tester, 'Disponibilidad');
      final consultas = _labelHeight(tester, 'Mis consultas');
      final historia = _labelHeight(tester, 'Historia clínica');

      expect(
        disponibilidad,
        closeTo(cartelera, 0.01),
        reason: 'Disponibilidad debe ocupar una línea, igual que Cartelera',
      );
      expect(
        consultas,
        lessThanOrEqualTo(cartelera * 2 + 0.01),
        reason: 'Mis consultas debe ocupar como máximo dos líneas',
      );
      expect(
        historia,
        lessThanOrEqualTo(cartelera * 2 + 0.01),
        reason: 'Historia clínica debe ocupar como máximo dos líneas',
      );
      expect(tester.takeException(), isNull);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('funcionario a 320 px mantiene las etiquetas en una línea', (
    tester,
  ) async {
    final container = await pumpApp(tester, size: const Size(320, 800));
    try {
      await _loginAs(tester, container, UserRole.funcionario);
      _expectNarrowShell(tester);

      final turnos = _labelHeight(tester, 'Turnos');
      final llegada = _labelHeight(tester, 'Llegada');
      final agendas = _labelHeight(tester, 'Agendas');

      expect(llegada, closeTo(turnos, 0.01));
      expect(agendas, closeTo(turnos, 0.01));
      expect(tester.takeException(), isNull);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets('a 900 px los tres roles conservan NavigationRail', (
    tester,
  ) async {
    for (final role in [
      UserRole.administrador,
      UserRole.socio,
      UserRole.funcionario,
    ]) {
      final container = await pumpApp(tester, size: const Size(900, 800));
      try {
        await _loginAs(tester, container, role);

        expect(tester.view.physicalSize, const Size(900, 800));
        expect(tester.view.devicePixelRatio, 1);
        expect(find.byType(NavigationRail), findsOneWidget, reason: role.name);
        expect(find.byType(NavigationBar), findsNothing, reason: role.name);
        expect(tester.takeException(), isNull, reason: role.name);
      } finally {
        await unmountApp(tester);
      }
    }
  });
}
