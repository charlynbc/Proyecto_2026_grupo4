import 'package:agenda_medica/features/estadisticas/consultas/widgets/appointment_status_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';
import 'appointment_statistics_fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  List<int> counts, {
  double width = 400,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: AppointmentStatusBars(
            statistics: statisticsOf(counts: counts),
          ),
        ),
      ),
    ),
  );
}

Finder _row(int i) => find.byKey(Key('stats-state-row-$i'));
Finder _track(int i) => find.byKey(Key('stats-state-track-$i'));
Finder _fill(int i) => find.byKey(Key('stats-state-fill-$i'));
Finder _count(int i) => find.byKey(Key('stats-state-count-$i'));

double _trackWidth(WidgetTester tester, int i) =>
    tester.getSize(_track(i)).width;

void main() {
  setUpAll(loadRoboto);

  group('siete filas en el orden fijo', () {
    testWidgets('cada fila lleva el nombre del estado y su cantidad', (
      tester,
    ) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3]);

      const counts = ['40', '110', '20', '8', '14', '5', '3'];
      for (var i = 0; i < 7; i++) {
        expect(
          find.descendant(of: _row(i), matching: find.text(statusLabels[i])),
          findsOneWidget,
          reason: 'nombre $i',
        );
        expect(
          find.descendant(of: _row(i), matching: find.text(counts[i])),
          findsOneWidget,
          reason: 'cantidad $i',
        );
      }
      expect(_row(7), findsNothing);
    });

    testWidgets('van de arriba hacia abajo en el orden fijo', (tester) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3]);

      final tops = [for (var i = 0; i < 7; i++) tester.getTopLeft(_row(i)).dy];
      expect(tops, [...tops]..sort());
      expect(tops.toSet(), hasLength(7));
    });

    testWidgets('la cantidad va al final de la fila, a la derecha de la '
        'barra', (tester) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3]);

      for (var i = 0; i < 7; i++) {
        expect(
          tester.getRect(_count(i)).left,
          greaterThanOrEqualTo(tester.getRect(_track(i)).right),
          reason: 'fila $i',
        );
      }
    });
  });

  group('escala común', () {
    testWidgets('8, 4, 2 y 1 miden 1, 1/2, 1/4 y 1/8 de la pista', (
      tester,
    ) async {
      await _pump(tester, [8, 4, 2, 1, 0, 0, 0]);

      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_fill(0)).width, closeTo(w, 0.5));
      expect(tester.getSize(_fill(1)).width, closeTo(w / 2, 0.5));
      expect(tester.getSize(_fill(2)).width, closeTo(w / 4, 0.5));
      expect(tester.getSize(_fill(3)).width, closeTo(w / 8, 0.5));
    });

    testWidgets('las pistas miden lo mismo en todas las filas', (tester) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3]);

      final w = _trackWidth(tester, 0);
      for (var i = 1; i < 7; i++) {
        expect(_trackWidth(tester, i), closeTo(w, 0.01), reason: 'fila $i');
      }
    });

    testWidgets('con 40 y 110 la escala es la de 110, no la de cada fila', (
      tester,
    ) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3]);

      final w = _trackWidth(tester, 0);
      // Agendada: 40 de 110. Atendida, la mayor: la pista entera.
      expect(tester.getSize(_fill(0)).width, closeTo(w * 40 / 110, 0.5));
      expect(tester.getSize(_fill(1)).width, closeTo(w, 0.5));
      expect(tester.getSize(_fill(2)).width, closeTo(w * 20 / 110, 0.5));
      expect(tester.getSize(_fill(3)).width, closeTo(w * 8 / 110, 0.5));
      expect(tester.getSize(_fill(4)).width, closeTo(w * 14 / 110, 0.5));
      expect(tester.getSize(_fill(5)).width, closeTo(w * 5 / 110, 0.5));
      expect(tester.getSize(_fill(6)).width, closeTo(w * 3 / 110, 0.5));
    });

    testWidgets('la barra empieza en el borde izquierdo de la pista', (
      tester,
    ) async {
      await _pump(tester, [8, 4, 2, 1, 0, 0, 0]);

      for (var i = 0; i < 4; i++) {
        expect(
          tester.getRect(_fill(i)).left,
          closeTo(tester.getRect(_track(i)).left, 0.01),
        );
      }
    });
  });

  group('cantidades en cero', () {
    testWidgets('un estado en cero no dibuja barra y dice 0', (tester) async {
      await _pump(tester, [8, 4, 0, 1, 0, 0, 0]);

      expect(_fill(2), findsNothing);
      expect(_fill(4), findsNothing);
      expect(_row(2), findsOneWidget);
      expect(
        find.descendant(of: _row(2), matching: find.text('0')),
        findsOneWidget,
      );
    });

    testWidgets('con todo en cero siguen las siete filas, sin barras', (
      tester,
    ) async {
      await _pump(tester, [0, 0, 0, 0, 0, 0, 0]);

      expect(find.byKey(const Key('stats-status-chart')), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(_row(i), findsOneWidget);
        expect(_fill(i), findsNothing, reason: 'fila $i');
        expect(
          find.descendant(of: _row(i), matching: find.text('0')),
          findsOneWidget,
        );
      }
    });

    testWidgets('con un solo estado, su barra llena la pista', (tester) async {
      await _pump(tester, [0, 7, 0, 0, 0, 0, 0]);

      expect(
        tester.getSize(_fill(1)).width,
        closeTo(_trackWidth(tester, 1), 0.5),
      );
      for (final i in [0, 2, 3, 4, 5, 6]) {
        expect(_fill(i), findsNothing, reason: 'fila $i');
      }
    });
  });

  group('lector de pantalla', () {
    testWidgets('cada fila dice su estado y su cantidad, con singular y '
        'plural', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [40, 1, 0, 8, 14, 5, 3]);

      expect(find.bySemanticsLabel('Agendada, 40 consultas'), findsOneWidget);
      expect(find.bySemanticsLabel('Atendida, 1 consulta'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Cancelada por el socio, 0 consultas'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Cancelada por la institución, 8 consultas'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('No se presentó a la consulta, 3 consultas'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('lo que se ve queda excluido y no se lee dos veces', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3]);

      expect(find.bySemanticsLabel('40'), findsNothing);
      expect(find.bySemanticsLabel('Agendada'), findsNothing);
      handle.dispose();
    });
  });

  group('a 320 px con el texto al doble', () {
    testWidgets('los nombres largos bajan de renglón sin cortarse', (
      tester,
    ) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3], width: 320, textScale: 2);
      expect(tester.takeException(), isNull);

      for (final label in statusLabels) {
        final finder = find.text(label);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
      }
      // "Cancelada por la institución" no entra en un renglón de 288 px a
      // doble tamaño: baja de renglón en lugar de cortarse.
      final oneLine = tester.getSize(find.text('Agendada')).height;
      expect(
        tester.getSize(find.text('Cancelada por la institución')).height,
        greaterThan(oneLine * 1.5),
      );
      expect(
        tester.getSize(find.text('No se presentó a la consulta')).height,
        greaterThan(oneLine * 1.5),
      );
    });

    testWidgets('las pistas y las cantidades quedan dentro del ancho', (
      tester,
    ) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3], width: 320, textScale: 2);

      for (var i = 0; i < 7; i++) {
        final track = tester.getRect(_track(i));
        expect(track.left, greaterThanOrEqualTo(0));
        expect(track.width, greaterThan(40), reason: 'pista $i');
        expect(tester.getRect(_count(i)).right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('no hay desplazamiento horizontal ni aviso', (tester) async {
      await _pump(tester, [40, 110, 20, 8, 14, 5, 3], width: 320, textScale: 2);

      expect(find.byKey(const Key('stats-chart-scroll-hint')), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
    });
  });
}
