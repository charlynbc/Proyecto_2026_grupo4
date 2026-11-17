import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/models/specialty_demand.dart';
import 'package:agenda_medica/features/estadisticas/especialidades/widgets/specialty_demand_bars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

SpecialtyDemandItem _item(
  int id,
  String name,
  int count, {
  bool referral = false,
}) => SpecialtyDemandItem(
  specialty: Specialty(id: id, name: name, requiresReferral: referral),
  count: count,
);

Future<void> _pump(
  WidgetTester tester,
  List<SpecialtyDemandItem> items, {
  double width = 400,
  double height = 4000,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
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
          child: SpecialtyDemandBars(items: items),
        ),
      ),
    ),
  );
}

Finder _row(int i) => find.byKey(Key('stats-row-$i'));
Finder _track(int i) => find.byKey(Key('stats-demand-track-$i'));
Finder _fill(int i) => find.byKey(Key('stats-demand-fill-$i'));
Finder _count(int i) => find.byKey(Key('stats-demand-count-$i'));
Finder _in(int row, String text) =>
    find.descendant(of: _row(row), matching: find.text(text));

double _trackWidth(WidgetTester tester, int i) =>
    tester.getSize(_track(i)).width;

void main() {
  setUpAll(loadRoboto);

  group('una fila por especialidad, en el orden en que llegan', () {
    final items = [
      _item(1, 'Medicina General', 128),
      _item(3, 'Cardiología', 42, referral: true),
      _item(4, 'Dermatología', 7, referral: true),
      _item(2, 'Pediatría', 0),
    ];

    testWidgets('cada fila lleva el nombre y la cantidad', (tester) async {
      await _pump(tester, items);

      expect(_in(0, 'Medicina General'), findsOneWidget);
      expect(_in(0, '128'), findsOneWidget);
      expect(_in(1, 'Cardiología'), findsOneWidget);
      expect(_in(1, '42'), findsOneWidget);
      expect(_in(2, 'Dermatología'), findsOneWidget);
      expect(_in(2, '7'), findsOneWidget);
      expect(_in(3, 'Pediatría'), findsOneWidget);
      expect(_in(3, '0'), findsOneWidget);
      expect(_row(4), findsNothing);
    });

    testWidgets('el orden es el del servidor aunque no sea descendente', (
      tester,
    ) async {
      await _pump(tester, [
        _item(1, 'Pediatría', 5),
        _item(2, 'Cardiología', 12),
        _item(3, 'Dermatología', 0),
        _item(4, 'Neurología', 12),
      ]);

      final names = ['Pediatría', 'Cardiología', 'Dermatología', 'Neurología'];
      final tops = [
        for (final name in names) tester.getTopLeft(find.text(name)).dy,
      ];
      expect(tops, [...tops]..sort());
      for (var i = 0; i < 4; i++) {
        expect(_in(i, names[i]), findsOneWidget, reason: 'fila $i');
      }
    });

    testWidgets('"Requiere pase" aparece solo donde corresponde', (
      tester,
    ) async {
      await _pump(tester, items);

      expect(_in(0, 'Requiere pase'), findsNothing);
      expect(_in(1, 'Requiere pase'), findsOneWidget);
      expect(_in(2, 'Requiere pase'), findsOneWidget);
      expect(_in(3, 'Requiere pase'), findsNothing);
      expect(find.text('Requiere pase'), findsNWidgets(2));
    });

    testWidgets('la cantidad va al final de la fila, a la derecha de la '
        'barra', (tester) async {
      await _pump(tester, items);

      for (var i = 0; i < 4; i++) {
        expect(
          tester.getRect(_count(i)).left,
          greaterThanOrEqualTo(tester.getRect(_track(i)).right),
          reason: 'fila $i',
        );
      }
    });
  });

  group('escala común', () {
    testWidgets('12, 6 y 3 miden 1, 1/2 y 1/4 de la pista', (tester) async {
      await _pump(tester, [
        _item(1, 'Cardiología', 12),
        _item(2, 'Pediatría', 6),
        _item(3, 'Dermatología', 3),
        _item(4, 'Neurología', 0),
      ]);

      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_fill(0)).width, closeTo(w, 0.5));
      expect(tester.getSize(_fill(1)).width, closeTo(w / 2, 0.5));
      expect(tester.getSize(_fill(2)).width, closeTo(w / 4, 0.5));
    });

    testWidgets('con 128, 42 y 7 la escala es la de 128, no la de cada fila', (
      tester,
    ) async {
      await _pump(tester, [
        _item(1, 'Medicina General', 128),
        _item(3, 'Cardiología', 42),
        _item(4, 'Dermatología', 7),
      ]);

      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_fill(0)).width, closeTo(w, 0.5));
      expect(tester.getSize(_fill(1)).width, closeTo(w * 42 / 128, 0.5));
      expect(tester.getSize(_fill(2)).width, closeTo(w * 7 / 128, 0.5));
    });

    testWidgets('la mayor no tiene que ser la primera', (tester) async {
      await _pump(tester, [
        _item(1, 'Pediatría', 5),
        _item(2, 'Cardiología', 20),
      ]);

      final w = _trackWidth(tester, 1);
      expect(tester.getSize(_fill(1)).width, closeTo(w, 0.5));
      expect(tester.getSize(_fill(0)).width, closeTo(w / 4, 0.5));
    });

    testWidgets('las pistas miden lo mismo en todas las filas', (tester) async {
      await _pump(tester, [
        _item(1, 'Medicina General', 1280),
        _item(2, 'Cardiología', 42),
        _item(3, 'Dermatología', 7),
      ]);

      final w = _trackWidth(tester, 0);
      expect(_trackWidth(tester, 1), closeTo(w, 0.01));
      expect(_trackWidth(tester, 2), closeTo(w, 0.01));
    });
  });

  group('cero consultas', () {
    testWidgets('una especialidad en cero no dibuja barra y dice 0', (
      tester,
    ) async {
      await _pump(tester, [
        _item(1, 'Cardiología', 12),
        _item(2, 'Pediatría', 0),
      ]);

      expect(_fill(1), findsNothing);
      expect(_row(1), findsOneWidget);
      expect(_in(1, '0'), findsOneWidget);
      expect(_fill(0), findsOneWidget);
    });

    testWidgets('con todas en cero se muestran igual las filas, sin barras', (
      tester,
    ) async {
      await _pump(tester, [
        _item(1, 'Cardiología', 0, referral: true),
        _item(2, 'Pediatría', 0),
      ]);

      expect(find.byKey(const Key('stats-demand-chart')), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        expect(_row(i), findsOneWidget);
        expect(_fill(i), findsNothing);
        expect(_in(i, '0'), findsOneWidget);
      }
      expect(_in(0, 'Requiere pase'), findsOneWidget);
    });

    testWidgets('sin especialidades no hay gráfico', (tester) async {
      await _pump(tester, const []);
      expect(find.byKey(const Key('stats-demand-chart')), findsNothing);
    });

    testWidgets('con una sola fila su barra llena la pista', (tester) async {
      await _pump(tester, [_item(1, 'Cardiología', 9, referral: true)]);

      expect(
        tester.getSize(_fill(0)).width,
        closeTo(_trackWidth(tester, 0), 0.5),
      );
      expect(_in(0, '9'), findsOneWidget);
      expect(_in(0, 'Requiere pase'), findsOneWidget);
    });
  });

  group('lector de pantalla', () {
    testWidgets('cada fila dice su nombre, su cantidad y si requiere pase', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _item(1, 'Cardiología', 12, referral: true),
        _item(2, 'Pediatría', 1),
        _item(3, 'Dermatología', 0, referral: true),
        _item(4, 'Medicina General', 128),
      ]);

      expect(
        find.bySemanticsLabel('Cardiología, 12 consultas, requiere pase'),
        findsOneWidget,
      );
      // Con exactamente 1 va en singular y sin la parte del pase.
      expect(find.bySemanticsLabel('Pediatría, 1 consulta'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Dermatología, 0 consultas, requiere pase'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Medicina General, 128 consultas'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('lo que se ve queda excluido y no se lee dos veces', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [_item(1, 'Cardiología', 12, referral: true)]);

      expect(find.bySemanticsLabel('12'), findsNothing);
      expect(find.bySemanticsLabel('Cardiología'), findsNothing);
      expect(find.bySemanticsLabel('Requiere pase'), findsNothing);
      handle.dispose();
    });
  });

  group('a 320 px con el texto al doble', () {
    const longName = 'Otorrinolaringología pediátrica y de cabeza y cuello';
    final items = [
      _item(1, longName, 128, referral: true),
      _item(2, 'Medicina física y rehabilitación', 7),
      _item(3, 'Odontología', 0),
    ];

    testWidgets('el nombre completo baja de renglón, sin puntos '
        'suspensivos', (tester) async {
      await _pump(tester, items, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);

      for (final name in [longName, 'Medicina física y rehabilitación']) {
        final finder = find.text(name);
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        expect(paragraph.didExceedMaxLines, isFalse, reason: name);
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0), reason: name);
        expect(rect.right, lessThanOrEqualTo(320), reason: name);
      }
      final oneLine = tester.getSize(find.text('Odontología')).height;
      expect(
        tester.getSize(find.text(longName)).height,
        greaterThan(oneLine * 2),
      );
    });

    testWidgets('"Requiere pase", las pistas y las cantidades quedan dentro '
        'del ancho', (tester) async {
      await _pump(tester, items, width: 320, textScale: 2);

      final pass = tester.getRect(_in(0, 'Requiere pase'));
      expect(pass.right, lessThanOrEqualTo(320));
      for (var i = 0; i < 2; i++) {
        final track = tester.getRect(_track(i));
        expect(track.left, greaterThanOrEqualTo(0));
        expect(track.width, greaterThan(40), reason: 'pista $i');
        expect(tester.getRect(_count(i)).right, lessThanOrEqualTo(320));
      }
      expect(tester.getRect(_count(2)).right, lessThanOrEqualTo(320));
    });

    testWidgets('no hay desplazamiento horizontal ni aviso', (tester) async {
      await _pump(tester, items, width: 320, textScale: 2);

      expect(find.byKey(const Key('stats-chart-scroll-hint')), findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
    });
  });

  group('con decenas de especialidades', () {
    final many = [
      for (var i = 0; i < 40; i++)
        _item(i + 1, 'Especialidad $i', 40 - i, referral: i.isEven),
    ];

    testWidgets('se muestran las 40 filas y el desplazamiento es vertical', (
      tester,
    ) async {
      await _pump(tester, many, width: 320, height: 600, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('stats-demand-chart')), findsOneWidget);
      // Las filas se construyen todas (no hay lista perezosa) y la última
      // queda fuera de la pantalla: se llega desplazando en vertical.
      expect(_row(39), findsOneWidget);
      expect(tester.getTopLeft(_row(39)).dy, greaterThan(600));
      expect(find.byKey(const Key('stats-chart-scroll-hint')), findsNothing);
    });

    testWidgets('la escala sigue siendo la de la mayor de las 40', (
      tester,
    ) async {
      await _pump(tester, many);

      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_fill(0)).width, closeTo(w, 0.5)); // 40 de 40
      expect(tester.getSize(_fill(30)).width, closeTo(w * 10 / 40, 0.5));
    });
  });
}
