import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/estadisticas/tabs/time_slot_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/models/time_slot_statistics.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/providers/time_slot_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/repositories/time_slot_statistics_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contrast.dart';
import '../../helpers/load_roboto.dart';

/// El mapa de calor de Franjas muestra solo las horas con actividad: desde la
/// primera hora con alguna cantidad (sumando los siete días) hasta la última,
/// con las horas vacías del medio incluidas. El servidor devuelve siempre las
/// 168 celdas (contrato, fila 71); acá las armamos igual, con ceros.

const _notice = 'Se ocultan las horas sin actividad al principio y al final';
const _noConsultations = 'No hay consultas en el período elegido.';
const _noArrivals = 'No hay llegadas en el período elegido.';

/// La grilla completa de 168 celdas: [counts] dice las que tienen actividad
/// (día ISO, hora) y el resto vale cero.
List<TimeSlotCell> _grid(Map<(int, int), int> counts) => [
  for (var day = 1; day <= 7; day++)
    for (var hour = 0; hour < 24; hour++)
      TimeSlotCell(day: day, hour: hour, count: counts[(day, hour)] ?? 0),
];

class _Repository implements TimeSlotStatisticsRepository {
  _Repository({
    this.consultations = const {},
    this.arrivals = const {},
    this.sparse,
  });

  final Map<(int, int), int> consultations;
  final Map<(int, int), int> arrivals;

  /// Si se indica, se devuelven estas celdas tal cual (sin la grilla entera).
  final List<TimeSlotCell>? sparse;

  @override
  Future<TimeSlotStatistics> statistics({
    DateTime? from,
    DateTime? to,
    int? specialtyId,
    required TimeSlotView view,
  }) async => TimeSlotStatistics(
    from: DateTime.utc(2026, 9, 1),
    to: DateTime.utc(2026, 9, 30),
    cells:
        sparse ??
        _grid(view == TimeSlotView.consultations ? consultations : arrivals),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(900, 3200),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        timeSlotStatisticsRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        specialtiesProvider.overrideWith(
          (ref) async => [
            const Specialty(
              id: 3,
              name: 'Medicina general',
              requiresReferral: false,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(child: TimeSlotStatisticsTab()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _label(int hour) =>
    '${hour.toString().padLeft(2, '0')}:00–${(hour + 1).toString().padLeft(2, '0')}:00';

/// Las etiquetas de hora que hay en pantalla ("09:00–10:00"), en orden.
List<String> _hourLabels(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(
    find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^\d\d:00–\d\d:00$').hasMatch(w.data ?? ''),
    ),
  ))
    text.data!,
];

void main() {
  group('solo las horas con actividad', () {
    testWidgets('con actividad entre las 09 y las 11 se ven las filas 09, 10 '
        'y 11 y ninguna otra', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3, (3, 10): 1, (5, 11): 2}),
      );

      expect(_hourLabels(tester), [_label(9), _label(10), _label(11)]);
      expect(find.text(_label(8)), findsNothing);
      expect(find.text(_label(12)), findsNothing);
      expect(find.text(_label(0)), findsNothing);
      expect(find.text(_label(23)), findsNothing);
    });

    testWidgets('con una sola hora con actividad se ve esa fila', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(4, 14): 5}));

      expect(_hourLabels(tester), [_label(14)]);
    });

    testWidgets('con actividad a las 00:00 y a las 23:00 se ven las 24 filas', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(1, 0): 1, (7, 23): 4}));

      expect(_hourLabels(tester), [for (var h = 0; h < 24; h++) _label(h)]);
    });

    testWidgets('una hora vacía en el medio sí se muestra', (tester) async {
      await _pump(tester, _Repository(consultations: {(1, 9): 2, (1, 12): 1}));

      expect(_hourLabels(tester), [
        _label(9),
        _label(10),
        _label(11),
        _label(12),
      ]);
      expect(find.text(_label(8)), findsNothing);
      expect(find.text(_label(13)), findsNothing);
    });

    testWidgets('la actividad se suma entre los siete días: una sola celda '
        'con cantidad alcanza para mostrar su hora', (tester) async {
      await _pump(tester, _Repository(consultations: {(7, 6): 1}));

      expect(_hourLabels(tester), [_label(6)]);
    });

    testWidgets('con las celdas que faltan (sin grilla entera) también '
        'recorta por actividad', (tester) async {
      await _pump(
        tester,
        _Repository(
          sparse: const [
            TimeSlotCell(day: 2, hour: 9, count: 2),
            TimeSlotCell(day: 2, hour: 10, count: 0),
            TimeSlotCell(day: 2, hour: 13, count: 0),
          ],
        ),
      );

      expect(_hourLabels(tester), [_label(9)]);
    });
  });

  group('la línea de aviso', () {
    testWidgets('dice exactamente el texto pedido cuando se oculta algo', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      expect(find.text(_notice), findsOneWidget);
    });

    testWidgets('va debajo del encabezado y antes de la grilla', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      final header = tester.getTopLeft(
        find.text('Cantidad por día y hora (hora de Uruguay)'),
      );
      final notice = tester.getTopLeft(find.text(_notice));
      final firstRow = tester.getTopLeft(find.text(_label(9)));
      expect(notice.dy, greaterThan(header.dy));
      expect(notice.dy, lessThan(firstRow.dy));
    });

    testWidgets('no aparece si hay actividad a las 00:00 y a las 23:00', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(1, 0): 1, (7, 23): 4}));

      expect(find.text(_notice), findsNothing);
    });

    testWidgets('aparece si solo se oculta el principio', (tester) async {
      await _pump(tester, _Repository(consultations: {(1, 0): 1, (7, 20): 4}));

      expect(_hourLabels(tester), hasLength(21));
      expect(find.text(_notice), findsOneWidget);
    });

    testWidgets('aparece si solo se oculta el final', (tester) async {
      await _pump(tester, _Repository(consultations: {(1, 3): 1, (7, 23): 4}));

      expect(_hourLabels(tester), hasLength(21));
      expect(find.text(_notice), findsOneWidget);
    });
  });

  group('sin actividad en todo el período', () {
    testWidgets('en Consultas no dibuja la grilla y lo dice', (tester) async {
      await _pump(tester, _Repository());

      expect(find.text(_noConsultations), findsOneWidget);
      expect(_hourLabels(tester), isEmpty);
      expect(find.text('Lun'), findsNothing);
      expect(find.text(_notice), findsNothing);
      expect(find.text('Datos del 01/09/2026 al 30/09/2026'), findsOneWidget);
    });

    testWidgets('en Llegadas no dibuja la grilla y dice llegadas', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));
      await tester.tap(find.text('Llegadas'));
      await tester.pumpAndSettle();

      expect(find.text(_noArrivals), findsOneWidget);
      expect(find.text(_noConsultations), findsNothing);
      expect(_hourLabels(tester), isEmpty);
    });

    testWidgets('el mensaje de cada vista es el suyo al cambiar de vista', (
      tester,
    ) async {
      await _pump(tester, _Repository(arrivals: {(3, 8): 2}));
      expect(find.text(_noConsultations), findsOneWidget);

      await tester.tap(find.text('Llegadas'));
      await tester.pumpAndSettle();
      expect(_hourLabels(tester), [_label(8)]);
      expect(find.text(_noConsultations), findsNothing);
      expect(find.text(_noArrivals), findsNothing);

      await tester.tap(find.text('Consultas'));
      await tester.pumpAndSettle();
      expect(find.text(_noConsultations), findsOneWidget);
      expect(_hourLabels(tester), isEmpty);
    });

    testWidgets('sin celdas en la respuesta también dice que no hay '
        'actividad', (tester) async {
      await _pump(tester, _Repository(sparse: const []));

      expect(find.text(_noConsultations), findsOneWidget);
    });
  });

  group('lo que se conserva', () {
    testWidgets('cada celda dice su cantidad y está bajo su día', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      expect(
        tester.getCenter(find.text('3')).dx,
        closeTo(tester.getCenter(find.text('Mar')).dx, 0.1),
      );
    });

    testWidgets('el texto alternativo de cada celda dice día, hora y '
        'cantidad', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Repository(consultations: {(2, 9): 3, (3, 10): 1}));

      expect(find.bySemanticsLabel(RegExp(r'^Mar 9:00, 3')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Mié 10:00, 1')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Lun 9:00, 0')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mayor cantidad, color más intenso', (tester) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 4, (3, 9): 1}));

      Color colorOf(String text) {
        final container = tester.widget<Container>(
          find
              .ancestor(of: find.text(text), matching: find.byType(Container))
              .first,
        );
        return container.color!;
      }

      final strong = colorOf('4');
      final weak = colorOf('1');
      final none = colorOf('0');
      expect(strong.a, greaterThanOrEqualTo(0));
      expect(
        HSLColor.fromColor(strong).lightness,
        lessThan(HSLColor.fromColor(weak).lightness),
      );
      expect(
        HSLColor.fromColor(weak).lightness,
        lessThan(HSLColor.fromColor(none).lightness),
      );
    });

    testWidgets('en pantalla angosta se desliza horizontalmente', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3}),
        size: const Size(320, 3200),
      );

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SingleChildScrollView &&
              w.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
      );
      expect(
        find.text('Deslizá horizontalmente para ver todos los días'),
        findsOneWidget,
      );
    });

    testWidgets('el filtro de especialidad sigue pidiendo de nuevo', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medicina general').last);
      await tester.pumpAndSettle();

      expect(_hourLabels(tester), [_label(9)]);
    });
  });

  group('a 320 px con Roboto y el texto al doble', () {
    setUpAll(loadRoboto);

    testWidgets('la línea de aviso no se corta', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3, (3, 11): 1}),
        size: const Size(320, 3200),
        textScale: 2,
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(_notice),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.text(_notice));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    });

    testWidgets('el mensaje de vacío no se corta', (tester) async {
      await _pump(
        tester,
        _Repository(),
        size: const Size(320, 3200),
        textScale: 2,
      );

      for (final text in [_noConsultations]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse, reason: text);
        expect(tester.getRect(find.text(text)).right, lessThanOrEqualTo(320));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('el mensaje de vacío de Llegadas tampoco se corta', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3}),
        size: const Size(320, 3200),
        textScale: 2,
      );
      await tester.tap(find.text('Llegadas'));
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(_noArrivals),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('escala de color secuencial', () {
    // Con máximo 10 el rango sale de la cantidad: 1 y 2 primer rango, 3 y 4
    // segundo, 5 y 6 tercero, 7 y 8 cuarto, 9 y 10 quinto. Contraste del
    // número con su fondo, calculado a mano ((L1 + 0,05) / (L2 + 0,05)):
    // cero 13,14; rango 1 14,34; rango 2 11,17; rango 3 7,55; rango 4 5,01
    // (blanco); rango 5 9,29 (blanco).
    const zero = (Color(0xFFE8E8E8), Color(0xFF212121), 13.14);
    const r1 = (Color(0xFFFFF3B0), Color(0xFF212121), 14.34);
    const r2 = (Color(0xFFFFD166), Color(0xFF212121), 11.17);
    const r3 = (Color(0xFFF79D3C), Color(0xFF212121), 7.55);
    const r4 = (Color(0xFFCC3A21), Color(0xFFFFFFFF), 5.01);
    const r5 = (Color(0xFF8B1A1A), Color(0xFFFFFFFF), 9.29);

    final counts = {
      (1, 9): 1,
      (2, 9): 2,
      (3, 9): 3,
      (4, 9): 4,
      (5, 9): 5,
      (6, 9): 6,
      (7, 9): 7,
      (1, 10): 8,
      (2, 10): 9,
      (3, 10): 10,
    };

    Color fillOf(WidgetTester tester, Finder text) => tester
        .widget<Container>(
          find.ancestor(of: text, matching: find.byType(Container)).first,
        )
        .color!;

    Color textColorOf(WidgetTester tester, Finder text) =>
        tester.widget<Text>(text).style!.color!;

    void expectShade(
      WidgetTester tester,
      Finder text,
      (Color, Color, double) shade,
      String reason,
    ) {
      final fill = fillOf(tester, text);
      final ink = textColorOf(tester, text);
      expect(fill, shade.$1, reason: '$reason: fondo');
      expect(ink, shade.$2, reason: '$reason: texto');
      final ratio = contrastRatio(ink, fill);
      expect(ratio, closeTo(shade.$3, 0.01), reason: '$reason: contraste');
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '$reason: minimo');
    }

    testWidgets('cada rango tiene su color y su color de texto', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: counts));

      final expected = {
        '1': r1,
        '2': r1,
        '3': r2,
        '4': r2,
        '5': r3,
        '6': r3,
        '7': r4,
        '8': r4,
        '9': r5,
        '10': r5,
      };
      for (final entry in expected.entries) {
        expectShade(tester, find.text(entry.key), entry.value, entry.key);
      }
    });

    testWidgets('las celdas en cero van en gris neutro', (tester) async {
      await _pump(tester, _Repository(consultations: counts));

      final zeros = find.text('0');
      expect(zeros, findsWidgets);
      for (var i = 0; i < zeros.evaluate().length; i++) {
        expectShade(tester, zeros.at(i), zero, 'cero $i');
      }
      final fill = fillOf(tester, zeros.first);
      // Gris: los tres canales iguales.
      expect(fill.r, fill.g);
      expect(fill.g, fill.b);
    });

    testWidgets('una celda sin dato también va en gris neutro', (tester) async {
      await _pump(
        tester,
        _Repository(
          sparse: const [
            TimeSlotCell(day: 2, hour: 9, count: 2),
            TimeSlotCell(day: 2, hour: 10, count: 0),
          ],
        ),
      );

      expectShade(tester, find.text('–').first, zero, 'sin dato');
      expectShade(tester, find.text('2'), r5, 'el unico dato es el maximo');
    });

    testWidgets('el rango sale de cantidad sobre máximo, no de valores '
        'fijos', (tester) async {
      // Máximo 3: 1 de 3 es el segundo rango, 2 de 3 el cuarto, 3 el quinto.
      await _pump(
        tester,
        _Repository(consultations: {(1, 9): 1, (2, 9): 2, (3, 9): 3}),
      );

      expectShade(tester, find.text('1'), r2, '1 de 3');
      expectShade(tester, find.text('2'), r4, '2 de 3');
      expectShade(tester, find.text('3'), r5, '3 de 3');
    });

    testWidgets('el recorrido es de claro a oscuro, sin perder luminancia '
        'entre rangos', (tester) async {
      await _pump(tester, _Repository(consultations: counts));

      final lums = [
        for (final t in ['1', '3', '5', '7', '9'])
          relativeLuminance(fillOf(tester, find.text(t))),
      ];
      // Luminancias a mano: 0,8850 / 0,6782 / 0,4421 / 0,1597 / 0,0630.
      expect(lums[0], closeTo(0.8850, 0.001));
      expect(lums[1], closeTo(0.6782, 0.001));
      expect(lums[2], closeTo(0.4421, 0.001));
      expect(lums[3], closeTo(0.1597, 0.001));
      expect(lums[4], closeTo(0.0630, 0.001));
      for (var i = 1; i < lums.length; i++) {
        expect(lums[i], lessThan(lums[i - 1]));
      }
    });

    testWidgets('la leyenda va de menor a mayor con los mismos colores', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: counts));

      Color swatchColor(Finder swatch) =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: swatch,
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color!;

      expect(find.byKey(const Key('timeslot-legend')), findsOneWidget);
      final shades = [r1, r2, r3, r4, r5];
      final xs = <double>[];
      for (var i = 0; i < 5; i++) {
        final swatch = find.byKey(Key('timeslot-legend-$i'));
        expect(swatch, findsOneWidget);
        expect(swatchColor(swatch), shades[i].$1, reason: 'rango ${i + 1}');
        xs.add(tester.getTopLeft(swatch).dx);
      }
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
      expect(tester.getTopLeft(find.text('Menos')).dx, lessThan(xs.first));
      expect(tester.getTopLeft(find.text('Más')).dx, greaterThan(xs.last));
      final zeroSwatch = find.byKey(const Key('timeslot-legend-zero'));
      expect(zeroSwatch, findsOneWidget);
      expect(swatchColor(zeroSwatch), zero.$1);
    });

    testWidgets('sin actividad no hay leyenda', (tester) async {
      await _pump(tester, _Repository());
      expect(find.byKey(const Key('timeslot-legend')), findsNothing);
    });
  });

  group('los datos no cambian', () {
    testWidgets('cada celda conserva su cantidad y su texto alternativo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3, (3, 10): 7, (5, 11): 10}),
      );

      expect(find.text('3'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      // 3 horas por 7 días son 21 celdas: 18 en cero.
      expect(find.text('0'), findsNWidgets(18));
      expect(
        find.bySemanticsLabel(RegExp(r'^Mar 9:00, 3(\n|$)')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Mié 10:00, 7(\n|$)')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Vie 11:00, 10(\n|$)')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Lun 9:00, 0(\n|$)')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('en Llegadas también', (tester) async {
      await _pump(tester, _Repository(arrivals: {(4, 8): 6}));
      await tester.tap(find.text('Llegadas'));
      await tester.pumpAndSettle();

      expect(find.text('6'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(6));
      expect(_hourLabels(tester), [_label(8)]);
    });
  });

  group('el aviso de desplazamiento', () {
    const notice = 'Deslizá horizontalmente para ver todos los días';

    ScrollableState horizontal(WidgetTester tester) => tester.state(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.horizontal,
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    final horizontalView = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );

    testWidgets('en pantalla ancha, donde la grilla entra, no aparece y no '
        'hay barra ni desplazamiento', (tester) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      expect(find.text(notice), findsNothing);
      expect(horizontalView, findsNothing);
      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('a 320 px aparece', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3}),
        size: const Size(320, 3200),
      );

      expect(find.text(notice), findsOneWidget);
      expect(horizontal(tester).position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('aparece si y solo si la grilla desborda, con cualquier '
        'ancho y tamaño de texto', (tester) async {
      for (final width in [320.0, 400.0, 500.0, 560.0, 600.0, 700.0, 900.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          await _pump(
            tester,
            _Repository(consultations: {(2, 9): 3}),
            size: Size(width, 3200),
            textScale: scale,
          );
          final reason = 'ancho $width, texto x$scale';
          if (find.text(notice).evaluate().isNotEmpty) {
            // Con aviso: hay barra y la grilla de verdad se pasa del ancho.
            expect(find.byType(Scrollbar), findsOneWidget, reason: reason);
            expect(
              horizontal(tester).position.maxScrollExtent,
              greaterThan(0),
              reason: reason,
            );
          } else {
            // Sin aviso: no hay barra ni desplazamiento y la grilla entra.
            expect(find.byType(Scrollbar), findsNothing, reason: reason);
            expect(horizontalView, findsNothing, reason: reason);
            expect(
              tester.getRect(find.text('Dom')).right,
              lessThanOrEqualTo(width - 16),
              reason: reason,
            );
          }
        }
      }
    });

    group('con Roboto, a 560 px (528 de contenido)', () {
      setUpAll(loadRoboto);

      // Medido: la grilla mide 495,6 px con el texto normal (entra) y 574,5
      // con el texto al doble (no entra).
      testWidgets('con el texto normal la grilla entra y no hay aviso', (
        tester,
      ) async {
        await _pump(
          tester,
          _Repository(consultations: {(2, 9): 3}),
          size: const Size(560, 3200),
        );

        expect(horizontalView, findsNothing);
        expect(find.byType(Scrollbar), findsNothing);
        expect(find.text(notice), findsNothing);
      });

      testWidgets('con el texto al doble la grilla no entra y aparece', (
        tester,
      ) async {
        await _pump(
          tester,
          _Repository(consultations: {(2, 9): 3}),
          size: const Size(560, 3200),
          textScale: 2,
        );

        expect(horizontal(tester).position.maxScrollExtent, greaterThan(40));
        expect(find.text(notice), findsOneWidget);
      });
    });
  });

  group('encabezado y etiquetas', () {
    const title = 'Cantidad por día y hora (hora de Uruguay)';

    testWidgets('el título es más grande y lo auxiliar más tenue', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      final titleText = tester.widget<Text>(find.text(title));
      final hours = tester.widget<Text>(find.text(_notice));
      expect(titleText.style!.fontSize, 16);
      expect(hours.style!.fontSize, 13);
      expect(hours.style!.height, 1.4);
      final theme = Theme.of(tester.element(find.text(title)));
      expect(hours.style!.color, theme.colorScheme.onSurfaceVariant);
    });

    testWidgets('la leyenda y el aviso de desplazamiento también van en 13 '
        'px con interlineado 1,4', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3}),
        size: const Size(320, 3200),
      );

      for (final text in [
        'Cero',
        'Menos',
        'Más',
        'Deslizá horizontalmente para ver todos los días',
      ]) {
        final style = tester.widget<Text>(find.text(text)).style!;
        expect(style.fontSize, 13, reason: text);
        expect(style.height, 1.4, reason: text);
      }
    });

    testWidgets('título, ayuda, leyenda y aviso son bloques separados por '
        '12 a 16 px', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3}),
        size: const Size(320, 3200),
      );

      Rect rect(String key) => tester.getRect(find.byKey(Key(key)));
      final blocks = [
        rect('timeslot-title'),
        rect('timeslot-hours-note'),
        rect('timeslot-legend'),
        rect('timeslot-scroll-hint'),
      ];
      for (var i = 1; i < blocks.length; i++) {
        final gap = blocks[i].top - blocks[i - 1].bottom;
        expect(gap, inInclusiveRange(12, 16), reason: 'entre bloque $i');
      }
    });

    testWidgets('sin horas ocultas ni desborde quedan título y leyenda, '
        'separados igual', (tester) async {
      await _pump(tester, _Repository(consultations: {(1, 0): 1, (7, 23): 4}));

      expect(find.byKey(const Key('timeslot-hours-note')), findsNothing);
      expect(find.byKey(const Key('timeslot-scroll-hint')), findsNothing);
      final gap =
          tester.getRect(find.byKey(const Key('timeslot-legend'))).top -
          tester.getRect(find.byKey(const Key('timeslot-title'))).bottom;
      expect(gap, inInclusiveRange(12, 16));
    });

    testWidgets('hay aire entre el último bloque y la grilla', (tester) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      final legendBottom = tester
          .getRect(find.byKey(const Key('timeslot-legend')))
          .bottom;
      final dayTop = tester.getTopLeft(find.text('Lun')).dy;
      expect(dayTop - legendBottom, greaterThanOrEqualTo(16));
    });

    testWidgets('la leyenda tiene espacio propio entre sus elementos', (
      tester,
    ) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      // Con el texto normal en pantalla ancha todo va en un renglón.
      final cero = tester.getRect(find.text('Cero'));
      final menos = tester.getRect(find.text('Menos'));
      final first = tester.getRect(find.byKey(const Key('timeslot-legend-0')));
      final last = tester.getRect(find.byKey(const Key('timeslot-legend-4')));
      final mas = tester.getRect(find.text('Más'));
      expect(menos.left - cero.right, greaterThanOrEqualTo(20));
      expect(first.left - menos.right, greaterThanOrEqualTo(8));
      expect(mas.left - last.right, greaterThanOrEqualTo(8));
    });

    testWidgets('si la leyenda baja de renglón hay 8 px entre renglones', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3}),
        size: const Size(320, 3200),
        textScale: 2,
      );

      final cero = tester.getRect(find.text('Cero'));
      final menos = tester.getRect(find.text('Menos'));
      expect(menos.top, greaterThan(cero.top));
      final swatchZero = tester.getRect(
        find.byKey(const Key('timeslot-legend-zero')),
      );
      final swatchScale = tester.getRect(
        find.byKey(const Key('timeslot-legend-0')),
      );
      final firstRowBottom = cero.bottom > swatchZero.bottom
          ? cero.bottom
          : swatchZero.bottom;
      final secondRowTop = menos.top < swatchScale.top
          ? menos.top
          : swatchScale.top;
      expect(secondRowTop - firstRowBottom, greaterThanOrEqualTo(8));
    });

    testWidgets('el aviso de desplazamiento lleva un icono de flechas '
        'horizontales al inicio', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3}),
        size: const Size(320, 3200),
      );

      final hint = find.byKey(const Key('timeslot-scroll-hint'));
      final icon = find.descendant(of: hint, matching: find.byType(Icon));
      expect(icon, findsOneWidget);
      expect(tester.widget<Icon>(icon).icon, Icons.swap_horiz);
      expect(tester.widget<Icon>(icon).size, 16);
      expect(
        tester.getRect(icon).right,
        lessThanOrEqualTo(
          tester
              .getRect(
                find.text('Deslizá horizontalmente para ver todos los días'),
              )
              .left,
        ),
      );
    });

    testWidgets('sin desborde no hay icono de aviso', (tester) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      expect(find.byKey(const Key('timeslot-scroll-hint')), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
    });

    testWidgets('las etiquetas de hora van en una sola línea', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3, (3, 11): 1}),
        size: const Size(320, 3200),
      );

      for (final hour in [9, 10, 11]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(_label(hour)),
        );
        // Una línea: tan alta como el nombre de un día, que no se parte.
        expect(
          paragraph.size.height,
          lessThanOrEqualTo(tester.getSize(find.text('Lun')).height * 1.1),
          reason: '$hour',
        );
      }
    });

    testWidgets('con el texto al doble siguen en una línea y la celda '
        'alcanza para su número', (tester) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3, (3, 11): 12}),
        size: const Size(320, 3200),
        textScale: 2,
      );

      for (final hour in [9, 10, 11]) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(_label(hour)),
        );
        // Una línea: tan alta como el nombre de un día, que no se parte.
        expect(
          paragraph.size.height,
          lessThanOrEqualTo(tester.getSize(find.text('Lun')).height * 1.1),
          reason: '$hour',
        );
      }
      final number = tester.getSize(find.text('12'));
      final cell = tester.getSize(
        find
            .ancestor(of: find.text('12'), matching: find.byType(Container))
            .first,
      );
      expect(cell.height, greaterThanOrEqualTo(number.height));
      expect(cell.width, greaterThanOrEqualTo(number.width));
      expect(tester.takeException(), isNull);
    });
  });

  group('barra de desplazamiento horizontal', () {
    final horizontalView = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );

    Future<void> narrow(WidgetTester tester, {double textScale = 1}) => _pump(
      tester,
      _Repository(consultations: {(2, 9): 3}),
      size: const Size(320, 3200),
      textScale: textScale,
    );

    testWidgets('a 320 px hay una barra siempre visible con su pista', (
      tester,
    ) async {
      await narrow(tester);

      final bar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(bar.thumbVisibility, isTrue);
      expect(bar.trackVisibility, isTrue);
      expect(bar.thickness, 8);
      expect(bar.controller, isNotNull);
      expect(
        tester.widget<SingleChildScrollView>(horizontalView).controller,
        same(bar.controller),
      );
      expect(
        find.descendant(of: find.byType(Scrollbar), matching: horizontalView),
        findsOneWidget,
      );
    });

    testWidgets('también con el texto al doble', (tester) async {
      await narrow(tester, textScale: 2);

      expect(find.byType(Scrollbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin desborde no hay barra', (tester) async {
      await _pump(tester, _Repository(consultations: {(2, 9): 3}));

      expect(find.byType(Scrollbar), findsNothing);
    });

    testWidgets('el color de la barra contrasta con el fondo crema', (
      tester,
    ) async {
      await narrow(tester);

      // Contrastes a mano. Luminancias: crema #F4EEE2 0,8587; pulgar #4A5560
      // 0,0880; pista #8C8472 0,2329. Pulgar sobre crema 6,59; pista sobre
      // crema (0,8587 + 0,05) / (0,2329 + 0,05) = 3,21; pulgar sobre pista
      // (0,2329 + 0,05) / (0,0880 + 0,05) = 2,05.
      const cream = Color(0xFFF4EEE2);
      final theme = ScrollbarTheme.of(tester.element(horizontalView));
      final thumb = theme.thumbColor!.resolve(<WidgetState>{})!;
      final track = theme.trackColor!.resolve(<WidgetState>{})!;
      expect(thumb, const Color(0xFF4A5560));
      expect(track, const Color(0xFFD8D0BF));
      expect(contrastRatio(thumb, cream), closeTo(6.59, 0.01));
      expect(contrastRatio(track, cream), closeTo(1.33, 0.01));
      expect(contrastRatio(thumb, track), closeTo(4.96, 0.01));
      expect(contrastRatio(track, cream), lessThan(3));
      expect(contrastRatio(thumb, track), greaterThanOrEqualTo(1.5));
    });

    testWidgets('el Scrollbar es interactivo', (tester) async {
      await narrow(tester);

      expect(
        tester.widget<Scrollbar>(find.byType(Scrollbar)).interactive,
        true,
      );
    });

    // El pulgar se arrastra en cualquier plataforma y con cualquier puntero.
    for (final (platform, kind, name) in [
      (TargetPlatform.android, PointerDeviceKind.touch, 'Android con el dedo'),
      (TargetPlatform.windows, PointerDeviceKind.mouse, 'Windows con el mouse'),
      (TargetPlatform.windows, PointerDeviceKind.touch, 'Windows con el dedo'),
    ]) {
      testWidgets('arrastrar el pulgar desplaza la grilla: $name', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        await narrow(tester);
        await tester.pumpAndSettle();

        final view = tester.getRect(horizontalView);
        final start = Offset(view.left + 30, view.bottom - 5);
        final before = tester.getTopLeft(find.text('Dom')).dx;
        final gesture = await tester.startGesture(start, kind: kind);
        await gesture.moveBy(const Offset(40, 0));
        await gesture.moveBy(const Offset(40, 0));
        await gesture.up();
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;

        expect(tester.getTopLeft(find.text('Dom')).dx, lessThan(before));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('se puede deslizar sin errores y la grilla se mueve', (
      tester,
    ) async {
      await narrow(tester);

      final before = tester.getTopLeft(find.text('Dom')).dx;
      await tester.drag(horizontalView, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Dom')).dx, lessThan(before));
      final bar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      bar.controller!.jumpTo(bar.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('al salir de la pantalla el controlador se libera sin '
        'errores', (tester) async {
      await narrow(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('si el ancho crece y la grilla entra, la barra se va', (
      tester,
    ) async {
      await narrow(tester);
      expect(find.byType(Scrollbar), findsOneWidget);

      tester.view.physicalSize = const Size(900, 3200);
      await tester.pumpAndSettle();

      expect(find.byType(Scrollbar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el desplazamiento no cambia las cantidades', (tester) async {
      await narrow(tester);
      await tester.drag(horizontalView, const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(6));
    });
  });

  group('a 320 px con Roboto y el texto al doble, la grilla', () {
    setUpAll(loadRoboto);

    testWidgets('no desborda, se desliza y la leyenda no se corta', (
      tester,
    ) async {
      await _pump(
        tester,
        _Repository(consultations: {(2, 9): 3, (3, 11): 12}),
        size: const Size(320, 3200),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final legend = tester.getRect(find.byKey(const Key('timeslot-legend')));
      expect(legend.left, greaterThanOrEqualTo(0));
      expect(legend.right, lessThanOrEqualTo(320));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Deslizá horizontalmente para ver todos los días'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
    });
  });
}
