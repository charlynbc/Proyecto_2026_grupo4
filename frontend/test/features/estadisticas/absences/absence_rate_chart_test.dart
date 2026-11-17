import 'package:agenda_medica/features/estadisticas/absences/models/absence_statistics.dart';
import 'package:agenda_medica/features/estadisticas/absences/repositories/absence_statistics_repository.dart';
import 'package:agenda_medica/features/estadisticas/absences/widgets/absence_rate_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

/// Un grupo con el porcentaje y el texto indicados. El ancho de la barra sale
/// del porcentaje que manda el servidor; el conteo de la fila, de `noShow` más
/// `missed` sobre `total`.
AbsenceGroup _group(
  String name,
  num percentage,
  String text, {
  String? lastName,
  int id = 1,
  int noShow = 0,
  int missed = 0,
  int notAttended = 0,
  int total = 1,
}) => AbsenceGroup(
  id: id,
  name: name,
  lastName: lastName,
  attended: total - noShow - missed - notAttended,
  noShow: noShow,
  missed: missed,
  notAttended: notAttended,
  total: total,
  percentage: percentage.toDouble(),
  percentageText: text,
);

Future<void> _pump(
  WidgetTester tester,
  List<AbsenceGroup> items, {
  double width = 400,
  double textScale = 1,
  AbsenceGrouping grouping = AbsenceGrouping.specialty,
}) async {
  tester.view.physicalSize = Size(width, 3000);
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
          child: AbsenceRateChart(items: items, grouping: grouping),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Medir algo que no está tiene que fallar como una aserción y no como un
/// error del buscador.
extension on WidgetTester {
  Size sizeOf(Finder finder) {
    expect(finder, findsOneWidget);
    return getSize(finder);
  }

  Rect rectOf(Finder finder) {
    expect(finder, findsOneWidget);
    return getRect(finder);
  }

  RenderParagraph paragraphOf(Finder finder) {
    expect(finder, findsOneWidget);
    return renderObject<RenderParagraph>(finder);
  }
}

Finder _track(int index) => find.byKey(Key('absence-bar-track-$index'));
Finder _fill(int index) => find.byKey(Key('absence-bar-fill-$index'));

/// Qué parte de la pista ocupa la barra.
double _ratio(WidgetTester tester, int index) =>
    tester.sizeOf(_fill(index)).width / tester.sizeOf(_track(index)).width;

int _lineCount(RenderParagraph paragraph, int start, int end) => {
  for (final box in paragraph.getBoxesForSelection(
    TextSelection(baseOffset: start, extentOffset: end),
  ))
    box.top.round(),
}.length;

void main() {
  setUpAll(loadRoboto);

  group('las barras', () {
    testWidgets('el ancho es el porcentaje sobre 100: 0, 12, 40 y 100 %', (
      tester,
    ) async {
      await _pump(tester, [
        _group('Medicina General', 100, '100 %', id: 1),
        _group('Traumatología', 40, '40 %', id: 2),
        _group('Cardiología', 12, '12 %', id: 3),
        _group('Pediatría', 0, '0 %', id: 4),
      ]);

      expect(_ratio(tester, 0), closeTo(1.0, 0.001));
      expect(_ratio(tester, 1), closeTo(0.40, 0.001));
      expect(_ratio(tester, 2), closeTo(0.12, 0.001));
      expect(tester.sizeOf(_fill(3)).width, 0);
    });

    testWidgets('el porcentaje con decimales no se redondea', (tester) async {
      await _pump(tester, [_group('Cardiología', 12.5, '12,5 %')]);

      expect(_ratio(tester, 0), closeTo(0.125, 0.001));
    });

    testWidgets('todas las pistas miden lo mismo aunque el valor sea más '
        'ancho', (tester) async {
      await _pump(tester, [
        _group('Medicina General', 100, '100 %', id: 1),
        _group('Pediatría', 8, '8 %', id: 2),
      ]);

      expect(tester.sizeOf(_track(0)).width, tester.sizeOf(_track(1)).width);
    });

    testWidgets('la barra de 0 % se ve como pista vacía con su valor escrito', (
      tester,
    ) async {
      await _pump(tester, [_group('Pediatría', 0, '0 %')]);

      expect(tester.sizeOf(_track(0)).width, greaterThan(0));
      expect(tester.sizeOf(_track(0)).height, greaterThan(0));
      expect(find.text('0 %'), findsOneWidget);
    });

    testWidgets('los colores salen del tema: barra primary y pista de '
        'superficie', (tester) async {
      await _pump(tester, [_group('Traumatología', 40, '40 %')]);
      final scheme = Theme.of(tester.element(find.byType(AbsenceRateChart)))
          .colorScheme;

      BoxDecoration decoration(Finder finder) {
        expect(finder, findsOneWidget);
        return tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;
      }

      expect(decoration(_fill(0)).color, scheme.primary);
      expect(decoration(_track(0)).color, scheme.surfaceContainerHighest);
    });
  });

  group('las filas', () {
    testWidgets('van en el mismo orden en que llegan, sin reordenar', (
      tester,
    ) async {
      await _pump(tester, [
        _group('Cardiología', 12, '12 %', id: 1),
        _group('Traumatología', 40, '40 %', id: 2),
        _group('Pediatría', 0, '0 %', id: 3),
      ]);

      final cardiology = tester.rectOf(find.text('Cardiología')).top;
      final trauma = tester.rectOf(find.text('Traumatología')).top;
      final pediatrics = tester.rectOf(find.text('Pediatría')).top;
      expect(cardiology, lessThan(trauma));
      expect(trauma, lessThan(pediatrics));
    });

    testWidgets('el nombre va arriba de la barra y el valor al final', (
      tester,
    ) async {
      await _pump(tester, [_group('Traumatología', 40, '40 %')]);

      final name = tester.rectOf(find.text('Traumatología'));
      final track = tester.rectOf(_track(0));
      final value = tester.rectOf(find.text('40 %'));
      expect(name.bottom, lessThanOrEqualTo(track.top));
      expect(value.left, greaterThanOrEqualTo(track.right));
      expect(value.center.dy, closeTo(track.center.dy, 8));
    });

    testWidgets('cada fila dice cuántas inasistencias hubo: 0, 1 y 4', (
      tester,
    ) async {
      await _pump(tester, [
        _group('Cardiología', 0, '0 %', id: 1, total: 10),
        _group('Pediatría', 100, '100 %', id: 2, noShow: 1, total: 1),
        _group(
          'Oftalmología',
          40,
          '40 %',
          id: 3,
          noShow: 3,
          missed: 1,
          total: 10,
        ),
      ]);

      expect(find.text('0 inasistencias de 10'), findsOneWidget);
      expect(find.text('1 inasistencia de 1'), findsOneWidget);
      expect(find.text('4 inasistencias de 10'), findsOneWidget);
      expect(find.text('1 inasistencias de 1'), findsNothing);
    });

    testWidgets('el total del conteo es el del servidor: incluye las no '
        'atendidas y las inasistencias no las incluyen', (tester) async {
      // 5 atendidas + 2 no asistió + 1 no se presentó + 2 no atendidas = 10.
      await _pump(tester, [
        _group(
          'Cardiología',
          30,
          '30 %',
          noShow: 2,
          missed: 1,
          notAttended: 2,
          total: 10,
        ),
      ]);

      expect(find.text('3 inasistencias de 10'), findsOneWidget);
    });

    testWidgets('el conteo va entre el nombre y la barra', (tester) async {
      await _pump(tester, [
        _group('Traumatología', 40, '40 %', noShow: 8, total: 20),
      ]);

      final name = tester.rectOf(find.text('Traumatología'));
      final count = tester.rectOf(find.text('8 inasistencias de 20'));
      final track = tester.rectOf(_track(0));
      expect(count.top, greaterThanOrEqualTo(name.bottom));
      expect(count.bottom, lessThanOrEqualTo(track.top));
    });

    testWidgets('las filas llevan la clave stats-row con su posición', (
      tester,
    ) async {
      await _pump(tester, [
        _group('Cardiología', 12, '12 %', id: 1),
        _group('Pediatría', 0, '0 %', id: 2),
      ]);

      expect(find.byKey(const Key('stats-row-0')), findsOneWidget);
      expect(find.byKey(const Key('stats-row-1')), findsOneWidget);
      expect(find.byKey(const Key('stats-row-2')), findsNothing);
    });

    testWidgets('el nombre de un médico lleva su apellido', (tester) async {
      await _pump(tester, [
        _group('Carla', 40, '40 %', lastName: 'Méndez'),
      ], grouping: AbsenceGrouping.doctor);

      expect(find.text('Carla Méndez'), findsOneWidget);
    });

    testWidgets('con todos en 0 % las filas siguen y no falla', (tester) async {
      await _pump(tester, [
        _group('Cardiología', 0, '0 %', id: 1),
        _group('Pediatría', 0, '0 %', id: 2),
      ]);

      expect(_track(0), findsOneWidget);
      expect(_track(1), findsOneWidget);
      expect(find.text('0 %'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin grupos no dibuja nada', (tester) async {
      await _pump(tester, const []);

      expect(find.byKey(const Key('absence-chart-title')), findsNothing);
      expect(find.byType(DecoratedBox), findsNothing);
      expect(tester.getSize(find.byType(AbsenceRateChart)), Size.zero);
    });
  });

  group('el título', () {
    testWidgets('por especialidad', (tester) async {
      await _pump(tester, [_group('Cardiología', 12, '12 %')]);

      expect(
        find.text('Porcentaje de inasistencia por especialidad'),
        findsOneWidget,
      );
    });

    testWidgets('por médico', (tester) async {
      await _pump(tester, [
        _group('Carla', 40, '40 %', lastName: 'Méndez'),
      ], grouping: AbsenceGrouping.doctor);

      expect(
        find.text('Porcentaje de inasistencia por médico'),
        findsOneWidget,
      );
      expect(
        find.text('Porcentaje de inasistencia por especialidad'),
        findsNothing,
      );
    });
  });

  group('el texto alternativo', () {
    testWidgets('cada fila tiene su propio texto con nombre, conteo y '
        'porcentaje', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _group(
          'Cardiología',
          12,
          '12 %',
          id: 1,
          noShow: 2,
          missed: 1,
          total: 25,
        ),
        _group('Pediatría', 100, '100 %', id: 2, noShow: 1, total: 1),
        _group('Dermatología', 0, '0 %', id: 3, total: 10),
      ]);

      expect(
        find.bySemanticsLabel('Cardiología, 3 inasistencias de 25, 12 %'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Pediatría, 1 inasistencia de 1, 100 %'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Dermatología, 0 inasistencias de 10, 0 %'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('el médico va con nombre completo y apellido', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _group(
          'María Fernanda',
          45,
          '45 %',
          lastName: 'Rodríguez Altamirano',
          id: 1,
          noShow: 7,
          missed: 2,
          total: 20,
        ),
      ], grouping: AbsenceGrouping.doctor);

      expect(
        find.bySemanticsLabel(
          'María Fernanda Rodríguez Altamirano, 9 inasistencias de 20, 45 %',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('no hay un resumen aparte del gráfico', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _group('Traumatología', 40, '40 %', id: 1, noShow: 8, total: 20),
        _group('Cardiología', 0, '0 %', id: 2, total: 10),
      ]);

      expect(find.bySemanticsLabel(RegExp('Mayor inasistencia')), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Sin inasistencias')), findsNothing);
      handle.dispose();
    });

    testWidgets('el contenido de la fila no se anuncia aparte', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _group('Traumatología', 40, '40 %', id: 1, noShow: 8, total: 20),
        _group('Cardiología', 12, '12 %', id: 2, noShow: 3, total: 25),
      ]);

      expect(find.bySemanticsLabel('Traumatología'), findsNothing);
      expect(find.bySemanticsLabel('Cardiología'), findsNothing);
      expect(find.bySemanticsLabel('40 %'), findsNothing);
      expect(find.bySemanticsLabel('12 %'), findsNothing);
      expect(find.bySemanticsLabel('8 inasistencias de 20'), findsNothing);
      expect(find.bySemanticsLabel('3 inasistencias de 25'), findsNothing);
      handle.dispose();
    });
  });

  group('se muestran todos los grupos', () {
    /// `count` grupos que bajan de 3 en 3 desde 99 %, como los manda el
    /// servidor.
    List<AbsenceGroup> many(int count) => [
      for (var i = 0; i < count; i++)
        _group('Grupo ${i + 1}', 99 - i * 3, '${99 - i * 3} %', id: i + 1),
    ];

    int rows(WidgetTester tester) => find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'absence-bar-track-',
              ),
        )
        .evaluate()
        .length;

    testWidgets('con 10 grupos hay 10 filas', (tester) async {
      await _pump(tester, many(10));

      expect(rows(tester), 10);
    });

    testWidgets('con 12 grupos hay 12 filas', (tester) async {
      await _pump(tester, many(12));

      expect(rows(tester), 12);
      expect(find.text('Grupo 11'), findsOneWidget);
      expect(find.text('Grupo 12'), findsOneWidget);
      expect(find.byKey(const Key('stats-row-11')), findsOneWidget);
    });

    testWidgets('con 25 grupos hay 25 filas', (tester) async {
      await _pump(tester, many(25));

      expect(rows(tester), 25);
      expect(find.text('Grupo 25'), findsOneWidget);
      expect(find.byKey(const Key('stats-row-24')), findsOneWidget);
    });

    testWidgets('no hay aviso de que se muestran solo los mayores', (
      tester,
    ) async {
      await _pump(tester, many(25));

      expect(find.textContaining('mayores de'), findsNothing);
      expect(find.byKey(const Key('absence-chart-notice')), findsNothing);
    });

    testWidgets('van en el orden en que llegan', (tester) async {
      await _pump(tester, many(12));

      var previous = -1.0;
      for (var i = 1; i <= 12; i++) {
        final top = tester.rectOf(find.text('Grupo $i')).top;
        expect(top, greaterThan(previous), reason: 'Grupo $i');
        previous = top;
      }
    });
  });

  group('a 320 px con Roboto y el texto al doble', () {
    final longNames = [
      _group(
        'María Fernanda',
        45,
        '45 %',
        lastName: 'Rodríguez Altamirano',
        id: 1,
        noShow: 7,
        missed: 2,
        total: 20,
      ),
      _group(
        'Juan Sebastián',
        36,
        '36 %',
        lastName: 'Fernández Etcheverry',
        id: 2,
        noShow: 7,
        missed: 2,
        total: 25,
      ),
      _group(
        'Lucía Fernanda',
        12,
        '12 %',
        lastName: 'Bermúdez Castellanos',
        id: 3,
        noShow: 1,
        total: 13,
      ),
      _group('Santiago', 0, '0 %', lastName: 'Díaz', id: 4, total: 40),
    ];

    testWidgets('los nombres ocupan hasta dos líneas y no se parten', (
      tester,
    ) async {
      await _pump(
        tester,
        longNames,
        grouping: AbsenceGrouping.doctor,
        width: 320,
        textScale: 2,
      );

      for (final group in longNames) {
        final full = '${group.name} ${group.lastName}';
        final paragraph = tester.paragraphOf(find.text(full));
        expect(_lineCount(paragraph, 0, full.length), lessThanOrEqualTo(2));
        var start = 0;
        for (final word in full.split(' ')) {
          expect(
            _lineCount(paragraph, start, start + word.length),
            1,
            reason: '$word en $full',
          );
          start += word.length + 1;
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el conteo no se corta ni parte la palabra inasistencias', (
      tester,
    ) async {
      await _pump(
        tester,
        longNames,
        grouping: AbsenceGrouping.doctor,
        width: 320,
        textScale: 2,
      );

      for (final text in [
        '9 inasistencias de 20',
        '9 inasistencias de 25',
        '1 inasistencia de 13',
        '0 inasistencias de 40',
      ]) {
        final paragraph = tester.paragraphOf(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        expect(_lineCount(paragraph, 0, text.length), lessThanOrEqualTo(2));
        final word = text.contains('inasistencias')
            ? 'inasistencias'
            : 'inasistencia';
        final start = text.indexOf(word);
        expect(
          _lineCount(paragraph, start, start + word.length),
          1,
          reason: text,
        );
        expect(tester.rectOf(find.text(text)).right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el valor y la barra entran en el ancho', (tester) async {
      await _pump(
        tester,
        longNames,
        grouping: AbsenceGrouping.doctor,
        width: 320,
        textScale: 2,
      );

      for (var i = 0; i < longNames.length; i++) {
        expect(tester.sizeOf(_track(i)).width, greaterThan(0));
        final value = tester.rectOf(find.text(longNames[i].percentageText));
        expect(value.right, lessThanOrEqualTo(320));
        expect(
          value.left,
          greaterThanOrEqualTo(tester.rectOf(_track(i)).right),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el título no se corta', (tester) async {
      await _pump(
        tester,
        longNames,
        grouping: AbsenceGrouping.doctor,
        width: 320,
        textScale: 2,
      );

      final paragraph = tester.paragraphOf(
        find.text('Porcentaje de inasistencia por médico'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    });
  });
}
