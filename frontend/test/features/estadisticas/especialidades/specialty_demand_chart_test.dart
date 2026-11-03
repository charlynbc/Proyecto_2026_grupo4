import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/models/specialty_demand.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/widgets/specialty_demand_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

const _names = [
  'Medicina general',
  'Cardiología',
  'Oftalmología',
  'Dermatología',
  'Traumatología',
  'Pediatría',
];
const _counts = [67, 20, 20, 16, 13, 12];

final _items = [
  for (var i = 0; i < _names.length; i++)
    SpecialtyDemandItem(
      specialty: Specialty(id: i + 1, name: _names[i], requiresReferral: false),
      count: _counts[i],
    ),
];

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SpecialtyDemandChart(items: _items)),
    ),
  );
  await tester.pumpAndSettle();
}

/// El texto del eje X: se busca dentro del gráfico porque la lista de abajo
/// repite los mismos nombres.
RenderParagraph _label(WidgetTester tester, String name) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(BarChart), matching: find.text(name)),
    );

/// En cuántas líneas se dibuja el tramo `[start, end)` del texto: las cajas
/// de la selección se agrupan por su borde superior, una altura por línea.
int _lineCount(RenderParagraph paragraph, int start, int end) => {
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  ))
    box.top.round(),
}.length;

const _hintKey = Key('stats-chart-scroll-hint');
const _hintText =
    'Deslizá hacia los costados para ver todas las especialidades';

void main() {
  setUpAll(loadRoboto);

  group('indicador de desplazamiento', () {
    testWidgets('a 360 px hay una barra visible y el texto de ayuda', (
      tester,
    ) async {
      await _pump(tester, 360);

      expect(
        find.ancestor(
          of: find.byType(SingleChildScrollView),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollbar && w.thumbVisibility == true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(_hintKey), findsOneWidget);
      expect(find.text(_hintText), findsOneWidget);
    });

    testWidgets('a 1200 px el gráfico entra completo y no hay ayuda', (
      tester,
    ) async {
      await _pump(tester, 1200);

      expect(find.byKey(_hintKey), findsNothing);
      expect(find.text(_hintText), findsNothing);
    });

    testWidgets('a 360 px la etiqueta más alta del eje Y no queda recortada', (
      tester,
    ) async {
      await _pump(tester, 360);

      final chartTop = tester.getTopLeft(find.byType(SpecialtyDemandChart)).dy;
      final yLabels = find.descendant(
        of: find.byType(BarChart),
        matching: find.byWidgetPredicate(
          (w) => w is Text && int.tryParse(w.data ?? '') != null,
        ),
      );
      expect(yLabels, findsWidgets);
      final topmost = [
        for (final label in yLabels.evaluate())
          tester.getTopLeft(find.byWidget(label.widget)).dy,
      ].reduce((a, b) => a < b ? a : b);

      expect(topmost, greaterThanOrEqualTo(chartTop));
    });
  });

  for (final width in [1200.0, 360.0]) {
    group('con $width px de ancho', () {
      for (final name in _names.where((n) => !n.contains(' '))) {
        testWidgets('$name ocupa una sola línea', (tester) async {
          await _pump(tester, width);

          final paragraph = _label(tester, name);
          expect(_lineCount(paragraph, 0, name.length), 1);
        });
      }

      testWidgets('Medicina general no se parte dentro de una palabra', (
        tester,
      ) async {
        await _pump(tester, width);

        final paragraph = _label(tester, 'Medicina general');
        const text = 'Medicina general';
        expect(_lineCount(paragraph, 0, text.length), inInclusiveRange(1, 2));
        expect(_lineCount(paragraph, 0, 'Medicina'.length), 1);
        expect(_lineCount(paragraph, 'Medicina '.length, text.length), 1);
      });
    });
  }
}
