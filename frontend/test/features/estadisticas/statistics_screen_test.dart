import 'package:agenda_medica/features/auth/widgets/logout_button.dart';
import 'package:agenda_medica/features/estadisticas/screens/statistics_screen.dart';
import 'package:agenda_medica/features/estadisticas/tabs/appointment_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/shift_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/specialty_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que cada pestaña muestra se busca por el tipo del widget y nunca por su
/// texto: quien arma cada pestaña reemplaza el contenido, y esos cambios no
/// pueden romper estas pruebas.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: StatisticsScreen())),
  );
  await tester.pumpAndSettle();
}

/// Abre la pestaña. La barra se desplaza: en una pantalla angosta una pestaña
/// puede quedar fuera de la vista, así que primero se la trae a la vista.
Future<void> _openTab(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('encabezado', () {
    testWidgets('el título es "Estadísticas" y lleva el botón de cerrar '
        'sesión', (tester) async {
      await _pump(tester);

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Estadísticas'),
        ),
        findsOneWidget,
      );
      expect(find.byType(LogoutButton), findsOneWidget);
    });

    testWidgets('no tiene el botón de volver de la demo', (tester) async {
      await _pump(tester);

      expect(find.byTooltip('Volver'), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('no queda nada de la demo con datos de ejemplo', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.textContaining('(demo)'), findsNothing);
      expect(find.textContaining('de ejemplo'), findsNothing);
      expect(find.text('Reservas por profesional'), findsNothing);
    });
  });

  group('pestañas', () {
    testWidgets('son tres, en este orden y con estos textos', (tester) async {
      await _pump(tester);

      final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs;
      expect(
        [for (final tab in tabs) (tab as Tab).text],
        [
          'Demanda por especialidad',
          'Utilización por turno',
          'Consultas por estado',
        ],
      );
    });

    testWidgets('cada pestaña tiene su key', (tester) async {
      await _pump(tester);

      final keys = [
        for (final tab in tester.widget<TabBar>(find.byType(TabBar)).tabs)
          tab.key,
      ];
      expect(keys, [
        const Key('stats-tab-specialties'),
        const Key('stats-tab-shifts'),
        const Key('stats-tab-appointments'),
      ]);
      expect(find.byKey(const Key('stats-tab-specialties')), findsOneWidget);
      expect(find.byKey(const Key('stats-tab-shifts')), findsOneWidget);
      expect(find.byKey(const Key('stats-tab-appointments')), findsOneWidget);
    });

    testWidgets('el texto de cada pestaña se ve en la barra', (tester) async {
      await _pump(tester);

      expect(find.text('Demanda por especialidad'), findsOneWidget);
      expect(find.text('Utilización por turno'), findsOneWidget);
      expect(find.text('Consultas por estado'), findsOneWidget);
    });

    testWidgets('al abrir se ve la primera', (tester) async {
      await _pump(tester);

      expect(find.byType(SpecialtyStatisticsTab), findsOneWidget);
    });

    testWidgets('la segunda muestra su widget', (tester) async {
      await _pump(tester);

      await _openTab(tester, 'stats-tab-shifts');

      expect(find.byType(ShiftStatisticsTab), findsOneWidget);
    });

    testWidgets('la tercera muestra su widget', (tester) async {
      await _pump(tester);

      await _openTab(tester, 'stats-tab-appointments');

      expect(find.byType(AppointmentStatisticsTab), findsOneWidget);
    });

    testWidgets('se puede volver a la primera', (tester) async {
      await _pump(tester);
      await _openTab(tester, 'stats-tab-appointments');

      await _openTab(tester, 'stats-tab-specialties');

      expect(find.byType(SpecialtyStatisticsTab), findsOneWidget);
    });

    for (final width in [400.0, 320.0]) {
      testWidgets('con $width px de ancho no hay desbordes y se llega a las '
          'tres', (tester) async {
        await _pump(tester, size: Size(width, 800));
        expect(tester.takeException(), isNull);

        await _openTab(tester, 'stats-tab-shifts');
        expect(find.byType(ShiftStatisticsTab), findsOneWidget);

        await _openTab(tester, 'stats-tab-appointments');
        expect(find.byType(AppointmentStatisticsTab), findsOneWidget);

        await _openTab(tester, 'stats-tab-specialties');
        expect(find.byType(SpecialtyStatisticsTab), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('widgets de las pestañas', () {
    test('cada uno tiene constructor const y acepta key', () {
      const keyed = [
        SpecialtyStatisticsTab(key: Key('a')),
        ShiftStatisticsTab(key: Key('b')),
        AppointmentStatisticsTab(key: Key('c')),
      ];

      expect(keyed.map((widget) => widget.key), [
        const Key('a'),
        const Key('b'),
        const Key('c'),
      ]);
    });
  });
}
