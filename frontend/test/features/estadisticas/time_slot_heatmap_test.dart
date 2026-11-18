import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/estadisticas/tabs/time_slot_statistics_tab.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/models/time_slot_statistics.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/providers/time_slot_statistics_provider.dart';
import 'package:agenda_medica/features/estadisticas/time_slots/repositories/time_slot_statistics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
