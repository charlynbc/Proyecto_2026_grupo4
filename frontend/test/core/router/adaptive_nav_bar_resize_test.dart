import 'package:agenda_medica/core/fakes/datos_prueba.dart';
import 'package:agenda_medica/core/router/adaptive_nav_bar.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/auth/providers/auth_repository_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_app.dart';

/// Cambiar el ancho de la ventana en vivo, sin recargar, pasa por anchos
/// minúsculos (hasta 1 px) mientras el navegador redimensiona. La barra de
/// navegación tiene que sobrevivir a esos pasos en el mismo árbol.

const _labels = [
  'Usuarios',
  'Especialidades',
  'Consultorios',
  'Estadísticas',
  'Cartelera',
];

const _destinations = [
  AdaptiveNavDestination(
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    label: 'Usuarios',
  ),
  AdaptiveNavDestination(
    icon: Icons.local_hospital_outlined,
    selectedIcon: Icons.local_hospital,
    label: 'Especialidades',
  ),
  AdaptiveNavDestination(
    icon: Icons.meeting_room_outlined,
    selectedIcon: Icons.meeting_room,
    label: 'Consultorios',
  ),
  AdaptiveNavDestination(
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    label: 'Estadísticas',
  ),
  AdaptiveNavDestination(
    icon: Icons.campaign_outlined,
    selectedIcon: Icons.campaign,
    label: 'Cartelera',
  ),
];

/// Todos los anchos del recorrido: normal, angosto y los intermedios muy
/// chicos, de ida y de vuelta.
const _shrinking = [
  1280.0,
  320.0,
  100.0,
  40.0,
  1.0,
  40.0,
  100.0,
  320.0,
  1280.0,
];

Future<void> _resize(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 700);
  await tester.pump();
}

/// Todas las excepciones pendientes, una por línea, para el mensaje del test.
String _pending(WidgetTester tester) {
  final found = <String>[];
  Object? error;
  while ((error = tester.takeException()) != null) {
    found.add(error.toString().split('\n').first);
  }
  return found.join(' | ');
}

void main() {
  setUpAll(loadRoboto);

  Future<void> pumpBar(
    WidgetTester tester, {
    required int selected,
    double width = 1280,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: AdaptiveNavBar(
            destinations: _destinations,
            selectedIndex: selected,
            onSelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double indicatorWidth(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('adaptive-nav-indicator'))).width;

  group('la barra sola, en el mismo árbol', () {
    for (final selected in [0, 4]) {
      testWidgets('destino $selected: pasa por todos los anchos sin '
          'excepciones', (tester) async {
        await pumpBar(tester, selected: selected);

        for (final width in _shrinking) {
          await _resize(tester, width);
          expect(_pending(tester), isEmpty, reason: 'ancho $width, pump');
          await tester.pumpAndSettle();
          expect(_pending(tester), isEmpty, reason: 'ancho $width, settle');
        }
      });
    }

    testWidgets('con 1 px el indicador mide cero y no hay excepciones', (
      tester,
    ) async {
      await pumpBar(tester, selected: 4, width: 1280);
      await _resize(tester, 1);
      await tester.pumpAndSettle();

      expect(_pending(tester), isEmpty);
      expect(indicatorWidth(tester), 0);
    });

    testWidgets('con 3 px (menos que los 4 px de holgura) mide cero', (
      tester,
    ) async {
      await pumpBar(tester, selected: 0, width: 3);

      expect(_pending(tester), isEmpty);
      expect(indicatorWidth(tester), 0);
    });

    testWidgets('el indicador vuelve a 64 px al volver a 1280 px', (
      tester,
    ) async {
      await pumpBar(tester, selected: 4);
      await _resize(tester, 1);
      await tester.pumpAndSettle();
      await _resize(tester, 1280);
      await tester.pumpAndSettle();

      expect(_pending(tester), isEmpty);
      expect(indicatorWidth(tester), 64);
    });

    testWidgets('a 1280 px el indicador mide 64 px en cada destino', (
      tester,
    ) async {
      for (final selected in [0, 1, 2, 3, 4]) {
        await pumpBar(tester, selected: selected, width: 1280);
        expect(indicatorWidth(tester), 64, reason: 'destino $selected');
      }
    });

    testWidgets('a 320 px el indicador es el ancho de su ranura menos 4 px, '
        'con tope de 64', (tester) async {
      for (final selected in [0, 1, 2, 3, 4]) {
        await pumpBar(tester, selected: selected, width: 320);
        final slot = tester
            .getSize(find.byKey(Key('adaptive-nav-slot-$selected')))
            .width;
        final expected = slot - 4 < 64 ? slot - 4 : 64.0;
        expect(
          indicatorWidth(tester),
          closeTo(expected, 0.01),
          reason: 'destino $selected',
        );
        expect(_pending(tester), isEmpty);
      }
    });

    testWidgets('con el texto al doble sigue igual a 320 px y no falla al '
        'achicar', (tester) async {
      await pumpBar(tester, selected: 4, width: 320, textScale: 2);
      final before = indicatorWidth(tester);
      for (final width in [100.0, 1.0, 320.0]) {
        await _resize(tester, width);
        await tester.pumpAndSettle();
        expect(_pending(tester), isEmpty, reason: 'ancho $width');
      }
      expect(indicatorWidth(tester), closeTo(before, 0.01));
    });

    testWidgets('los rótulos siguen estando en cada destino', (tester) async {
      await pumpBar(tester, selected: 2, width: 320);
      for (final label in _labels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  group('en la app, como administrador en Cartelera', () {
    testWidgets('1280, 320 y los anchos chicos, de ida y de vuelta, sin '
        'excepciones', (tester) async {
      final container = await pumpApp(tester, size: const Size(1280, 800));
      final person = TestData.people.firstWhere(
        (p) => p.role == UserRole.administrador.apiValue,
      );
      final repo = await container.read(authRepositoryProvider.future);
      final login = repo.login(
        ci: person.ci,
        password: kTestPassword,
        access: AccessType.empleado,
      );
      await tester.pumpAndSettle();
      await login;
      await tester.pumpAndSettle();
      await goTo(tester, container, '/admin/cartelera');
      expect(_pending(tester), isEmpty, reason: 'antes de achicar');

      // 100 px no se prueba acá: es el contenido de la pantalla, no la
      // barra, el que se desborda con tan poco ancho.
      for (final width in [1280.0, 320.0, 40.0, 1.0, 40.0, 320.0, 1280.0]) {
        await _resize(tester, width);
        expect(_pending(tester), isEmpty, reason: 'ancho $width, pump');
        await tester.pumpAndSettle();
        expect(_pending(tester), isEmpty, reason: 'ancho $width, settle');
        // Menos de 600 px hay barra inferior; desde 600 px, riel lateral.
        expect(
          find.byType(AdaptiveNavBar),
          width < 600 ? findsOneWidget : findsNothing,
          reason: 'ancho $width',
        );
      }
      await unmountApp(tester);
    });
  });
}
