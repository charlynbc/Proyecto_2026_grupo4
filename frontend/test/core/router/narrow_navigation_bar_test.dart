import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/features/agenda/screens/availability_screen.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

void _expectCenteredLines(
  WidgetTester tester,
  String label,
  List<TextSelection> words,
) {
  final destination = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byWidgetPredicate(
      (widget) => widget is NavigationDestination && widget.label == label,
    ),
  );
  expect(destination, findsOneWidget);
  final text = find.descendant(of: destination, matching: find.text(label));
  expect(text, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(text);
  final icons = find.descendant(of: destination, matching: find.byType(Icon));
  expect(icons, findsWidgets);
  // Flutter superpone ambos iconos durante la transición; comparten el centro.
  final iconCenterX = tester.getCenter(icons.first).dx;

  // Cajas ajustadas a las palabras, sin espacios finales que sesguen el centro.
  // Se unen solo las palabras que Flutter realmente colocó en la misma línea.
  final lines = <Rect>[];
  for (final word in words) {
    final boxes = paragraph.getBoxesForSelection(word);
    expect(
      boxes,
      hasLength(1),
      reason: '$label: cada palabra debe estar entera',
    );
    final rect = boxes.single.toRect();
    final line = lines.indexWhere(
      (value) => (value.top - rect.top).abs() < 0.01,
    );
    if (line < 0) {
      lines.add(rect);
    } else {
      lines[line] = lines[line].expandToInclude(rect);
    }
  }
  expect(lines, isNotEmpty);
  for (final line in lines) {
    final centerX = paragraph.localToGlobal(line.center).dx;
    expect(
      centerX,
      closeTo(iconCenterX, 1),
      reason: '$label: cada línea debe estar centrada bajo su icono (1 px)',
    );
  }
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
      expect(locationOf(container), '/socio/inicio');
      expect(find.byType(NavigationBar), findsNothing);

      final shortcut = find.byKey(const Key('home-shortcut-disponibilidad'));
      expect(
        find.descendant(of: shortcut, matching: find.text('Reservar consulta')),
        findsOneWidget,
      );
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(locationOf(container), '/socio/disponibilidad');
      _expectNarrowShell(tester);

      final reservationLabel = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Reservar consulta'),
      );
      expect(reservationLabel, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Disponibilidad'),
        ),
        findsNothing,
      );
      final cartelera = _labelHeight(tester, 'Cartelera');
      final inicio = _labelHeight(tester, 'Inicio');
      final reservarConsulta = _labelHeight(tester, 'Reservar consulta');
      final consultas = _labelHeight(tester, 'Mis consultas');
      final historia = _labelHeight(tester, 'Historia clínica');

      expect(
        reservarConsulta,
        lessThanOrEqualTo(cartelera * 2 + 0.01),
        reason: 'Reservar consulta admite dos líneas con las palabras enteras',
      );
      expect(inicio, closeTo(cartelera, 0.01));
      final paragraph = tester.renderObject<RenderParagraph>(reservationLabel);
      // Rangos escritos a mano: Reservar [0, 8), consulta [9, 17).
      final reservarBoxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 8),
      );
      final consultaBoxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 9, extentOffset: 17),
      );
      expect(reservarBoxes, hasLength(1), reason: 'Reservar no debe partirse');
      expect(consultaBoxes, hasLength(1), reason: 'consulta no debe partirse');
      for (final box in [reservarBoxes.single, consultaBoxes.single]) {
        expect(box.left, greaterThanOrEqualTo(-0.01));
        expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.01));
      }
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
      // Rangos explícitos de las palabras de cada etiqueta de dos palabras.
      void expectSocioLabelsCentered() {
        _expectCenteredLines(tester, 'Reservar consulta', const [
          TextSelection(baseOffset: 0, extentOffset: 8),
          TextSelection(baseOffset: 9, extentOffset: 17),
        ]);
        _expectCenteredLines(tester, 'Mis consultas', const [
          TextSelection(baseOffset: 0, extentOffset: 3),
          TextSelection(baseOffset: 4, extentOffset: 13),
        ]);
        _expectCenteredLines(tester, 'Historia clínica', const [
          TextSelection(baseOffset: 0, extentOffset: 8),
          TextSelection(baseOffset: 9, extentOffset: 16),
        ]);
      }

      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations, hasLength(5));
      expect(bar.selectedIndex, 1);
      expectSocioLabelsCentered();

      await goTo(tester, container, '/socio/cartelera');
      expect(locationOf(container), '/socio/cartelera');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        4,
      );
      expectSocioLabelsCentered();
      expect(tester.takeException(), isNull);
    } finally {
      await unmountApp(tester);
    }
  });

  testWidgets(
    'el rail del socio muestra Reservar consulta y no Disponibilidad',
    (tester) async {
      final container = await pumpApp(tester, size: const Size(900, 800));
      try {
        await _loginAs(tester, container, UserRole.socio);
        expect(find.byType(NavigationRail), findsNothing);
        await goTo(tester, container, '/socio/disponibilidad');

        final rail = find.byType(NavigationRail);
        expect(rail, findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        final destination = find.descendant(
          of: rail,
          matching: find.text('Reservar consulta'),
        );
        expect(destination, findsOneWidget);
        expect(destination.hitTestable(), findsOneWidget);
        expect(
          find.descendant(of: rail, matching: find.text('Disponibilidad')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await unmountApp(tester);
      }
    },
  );

  testWidgets(
    'tocar Reservar consulta conserva la ruta /socio/disponibilidad',
    (tester) async {
      final container = await pumpApp(tester, size: const Size(320, 800));
      try {
        await _loginAs(tester, container, UserRole.socio);
        await goTo(tester, container, '/socio/cartelera');
        expect(locationOf(container), '/socio/cartelera');
        final destination = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Reservar consulta'),
        );
        expect(destination, findsOneWidget);
        expect(destination.hitTestable(), findsOneWidget);

        await tester.tap(destination);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );

        expect(locationOf(container), '/socio/disponibilidad');
        expect(find.byType(AvailabilityScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await unmountApp(tester);
      }
    },
  );

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

        if (role == UserRole.socio) {
          expect(find.byType(NavigationRail), findsNothing);
          await goTo(tester, container, '/socio/disponibilidad');
        }

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
