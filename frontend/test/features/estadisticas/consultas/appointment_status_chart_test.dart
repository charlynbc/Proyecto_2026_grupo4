import 'package:agenda_medica/features/estadisticas/consultas/models/appointment_statistics.dart';
import 'package:agenda_medica/features/estadisticas/consultas/widgets/appointment_status_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';
import 'appointment_statistics_fixtures.dart';

const _hintKey = Key('stats-chart-scroll-hint');
const _hintText = 'Deslizá hacia los costados para ver todos los estados';

Future<void> _pump(
  WidgetTester tester,
  double width, {
  AppointmentStatistics? statistics,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppointmentStatusChart(statistics: statistics ?? statisticsOf()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<BarChartGroupData> _groups(WidgetTester tester) =>
    tester.widget<BarChart>(find.byType(BarChart)).data.barGroups;

/// El texto del eje X: se busca dentro del gráfico.
Finder _labelFinder(String name) =>
    find.descendant(of: find.byType(BarChart), matching: find.text(name));

/// En cuántas líneas se dibuja el tramo `[start, end)` del texto: las cajas
/// de la selección se agrupan por su borde superior, una altura por línea.
int _lineCount(RenderParagraph paragraph, int start, int end) => {
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  ))
    box.top.round(),
}.length;

void main() {
  setUpAll(loadRoboto);

  group('barras', () {
    testWidgets('son siete, con las cantidades en el orden fijo', (
      tester,
    ) async {
      await _pump(tester, 1200);

      expect(_groups(tester), hasLength(7));
      expect(_groups(tester).map((g) => g.barRods.single.toY), [
        40,
        110,
        20,
        8,
        14,
        5,
        3,
      ]);
    });

    testWidgets('con total cero siguen las siete barras, todas en cero', (
      tester,
    ) async {
      await _pump(
        tester,
        1200,
        statistics: statisticsOf(
          counts: const [0, 0, 0, 0, 0, 0, 0],
          total: 0,
          cancelled: 0,
          percentage: null,
          percentageText: 'Sin datos',
        ),
      );

      expect(_groups(tester), hasLength(7));
      expect(_groups(tester).map((g) => g.barRods.single.toY), [
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
    });

    testWidgets('las etiquetas del eje X van en el orden fijo', (tester) async {
      await _pump(tester, 1200);

      final byPosition = [...statusLabels]
        ..sort(
          (a, b) => tester
              .getCenter(_labelFinder(a))
              .dx
              .compareTo(tester.getCenter(_labelFinder(b)).dx),
        );
      expect(byPosition, statusLabels);
    });
  });

  for (final width in [1200.0, 360.0]) {
    group('con $width px de ancho', () {
      for (final label in statusLabels) {
        testWidgets('"$label" no se parte ni se recorta', (tester) async {
          await _pump(tester, width);

          expect(_labelFinder(label), findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(
            _labelFinder(label),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          var offset = 0;
          for (final word in label.split(' ')) {
            expect(
              _lineCount(paragraph, offset, offset + word.length),
              1,
              reason: '"$word" dentro de "$label"',
            );
            offset += word.length + 1;
          }
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

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

      final chartTop = tester
          .getTopLeft(find.byType(AppointmentStatusChart))
          .dy;
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
}
