import 'package:agenda_medica/features/auth/widgets/logout_button.dart';
import 'package:agenda_medica/features/estadisticas/screens/statistics_screen.dart';
import 'package:agenda_medica/features/estadisticas/tabs/absence_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/appointment_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/shift_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/tabs/specialty_statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

/// Las keys y los textos de las pestañas de la barra, en orden.
const _tabKeys = [
  'stats-tab-specialties',
  'stats-tab-shifts',
  'stats-tab-appointments',
  'stats-tab-absences',
];
const _tabTexts = [
  'Demanda por especialidad',
  'Utilización por turno',
  'Consultas por estado',
  'Inasistencias',
];

/// El `Text` de la etiqueta de la pestaña [key].
Finder _tabLabel(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text));

/// En cuántas líneas se dibuja el tramo `[start, end)` del texto: las cajas
/// de la selección se agrupan por su borde superior, una altura por línea.
int _lineCount(RenderParagraph paragraph, int start, int end) => {
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  ))
    box.top.round(),
}.length;

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
    testWidgets('son cuatro, en este orden y con estos textos', (tester) async {
      await _pump(tester);

      expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(4));
      expect([
        for (final key in _tabKeys) tester.widget<Text>(_tabLabel(key)).data,
      ], _tabTexts);
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
        const Key('stats-tab-absences'),
      ]);
      expect(find.byKey(const Key('stats-tab-specialties')), findsOneWidget);
      expect(find.byKey(const Key('stats-tab-shifts')), findsOneWidget);
      expect(find.byKey(const Key('stats-tab-appointments')), findsOneWidget);
      expect(find.byKey(const Key('stats-tab-absences')), findsOneWidget);
    });

    testWidgets('el texto de cada pestaña se ve en la barra', (tester) async {
      await _pump(tester);

      expect(find.text('Demanda por especialidad'), findsOneWidget);
      expect(find.text('Utilización por turno'), findsOneWidget);
      expect(find.text('Consultas por estado'), findsOneWidget);
      expect(find.text('Inasistencias'), findsOneWidget);
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

    testWidgets('la cuarta muestra su widget', (tester) async {
      await _pump(tester);

      await _openTab(tester, 'stats-tab-absences');

      expect(find.byType(AbsenceStatisticsTab), findsOneWidget);
    });

    testWidgets('se puede volver a la primera', (tester) async {
      await _pump(tester);
      await _openTab(tester, 'stats-tab-appointments');

      await _openTab(tester, 'stats-tab-specialties');

      expect(find.byType(SpecialtyStatisticsTab), findsOneWidget);
    });

    for (final width in [400.0, 360.0, 320.0]) {
      testWidgets('con $width px de ancho no hay desbordes y se llega a las '
          'cuatro', (tester) async {
        await _pump(tester, size: Size(width, 800));
        expect(tester.takeException(), isNull);

        await _openTab(tester, 'stats-tab-shifts');
        expect(find.byType(ShiftStatisticsTab), findsOneWidget);

        await _openTab(tester, 'stats-tab-appointments');
        expect(find.byType(AppointmentStatisticsTab), findsOneWidget);

        await _openTab(tester, 'stats-tab-absences');
        expect(find.byType(AbsenceStatisticsTab), findsOneWidget);

        await _openTab(tester, 'stats-tab-specialties');
        expect(find.byType(SpecialtyStatisticsTab), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('las pestañas se ven siempre enteras', () {
    setUpAll(loadRoboto);

    for (final width in [320.0, 360.0, 400.0, 900.0]) {
      group('con $width px de ancho', () {
        testWidgets('cada pestaña queda completa dentro de la pantalla', (
          tester,
        ) async {
          await _pump(tester, size: Size(width, 800));

          for (final key in _tabKeys) {
            final rect = tester.getRect(find.byKey(Key(key)));
            expect(rect.left, greaterThanOrEqualTo(0), reason: key);
            expect(rect.right, lessThanOrEqualTo(width), reason: key);
          }
          expect(tester.takeException(), isNull);
        });

        testWidgets('la barra no se desplaza', (tester) async {
          await _pump(tester, size: Size(width, 800));

          expect(
            find.descendant(
              of: find.byType(TabBar),
              matching: find.byType(Scrollable),
            ),
            findsNothing,
          );
        });

        testWidgets('ninguna palabra se parte ni se recorta', (tester) async {
          await _pump(tester, size: Size(width, 800));

          for (var i = 0; i < _tabKeys.length; i++) {
            final label = _tabTexts[i];
            final paragraph = tester.renderObject<RenderParagraph>(
              find
                  .descendant(
                    of: find.byKey(Key(_tabKeys[i])),
                    matching: find.byType(RichText),
                  )
                  .first,
            );
            expect(paragraph.didExceedMaxLines, isFalse, reason: label);
            var offset = 0;
            for (final word in label.split(' ')) {
              final end = offset + word.length;
              // Cada palabra ocupa una sola línea...
              expect(
                _lineCount(paragraph, offset, end),
                1,
                reason: '"$word" dentro de "$label"',
              );
              // ...y entra dentro de la caja del texto. Se mide palabra por
              // palabra y no el texto entero: el espacio que queda al final de
              // un renglón sobresale de la caja sin recortar nada.
              for (final box in paragraph.getBoxesForSelection(
                TextSelection(baseOffset: offset, extentOffset: end),
              )) {
                expect(
                  box.right,
                  lessThanOrEqualTo(paragraph.size.width),
                  reason: '"$word" dentro de "$label"',
                );
              }
              offset = end + 1;
            }
          }
        });

        testWidgets('tocar la tercera la abre sin desplazar la barra', (
          tester,
        ) async {
          await _pump(tester, size: Size(width, 800));

          await tester.tap(find.byKey(const Key('stats-tab-appointments')));
          await tester.pumpAndSettle();

          expect(find.byType(AppointmentStatisticsTab), findsOneWidget);
        });
      });
    }

    testWidgets('a 360 px la tercera pestaña empieza dentro de la pantalla', (
      tester,
    ) async {
      await _pump(tester, size: const Size(360, 800));

      final third = tester.getRect(
        find.byKey(const Key('stats-tab-appointments')),
      );
      expect(third.left, lessThan(360));
    });

    testWidgets('las pestañas se reparten el ancho de la barra', (
      tester,
    ) async {
      await _pump(tester, size: const Size(900, 800));

      final centers = [
        for (final key in _tabKeys) tester.getCenter(find.byKey(Key(key))).dx,
      ];
      expect(centers[0], lessThan(centers[1]));
      expect(centers[1], lessThan(centers[2]));
      expect(centers[2], lessThan(centers[3]));
      // Cada una en su cuarto de la pantalla.
      expect(centers[0], lessThan(225));
      expect(centers[1], inInclusiveRange(225, 450));
      expect(centers[2], inInclusiveRange(450, 675));
      expect(centers[3], greaterThan(675));
    });
  });

  group('widgets de las pestañas', () {
    test('cada uno tiene constructor const y acepta key', () {
      const keyed = [
        SpecialtyStatisticsTab(key: Key('a')),
        ShiftStatisticsTab(key: Key('b')),
        AppointmentStatisticsTab(key: Key('c')),
        AbsenceStatisticsTab(key: Key('d')),
      ];

      expect(keyed.map((widget) => widget.key), [
        const Key('a'),
        const Key('b'),
        const Key('c'),
        const Key('d'),
      ]);
    });
  });
}
