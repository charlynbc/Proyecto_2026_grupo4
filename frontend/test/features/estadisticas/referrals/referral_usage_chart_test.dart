import 'package:agenda_medica/features/estadisticas/referrals/models/referral_statistics.dart';
import 'package:agenda_medica/features/estadisticas/referrals/widgets/referral_usage_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/load_roboto.dart';

/// Una especialidad de destino. `emitidos` sale de la suma, salvo que se
/// indique otro valor: la escala del gráfico no tiene que depender de él.
ReferralItem _item(
  String name,
  int used,
  int available,
  int expired, {
  int? issued,
  String utilization = 'Sin datos',
  bool requiresReferral = true,
}) => ReferralItem(
  name: name,
  requiresReferral: requiresReferral,
  issued: issued ?? used + available + expired,
  used: used,
  available: available,
  expired: expired,
  percentage: null,
  utilization: utilization,
);

Future<void> _pump(
  WidgetTester tester,
  List<ReferralItem> items, {
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
          child: ReferralUsageChart(items: items),
        ),
      ),
    ),
  );
}

Finder _track(int row) => find.byKey(Key('referral-track-$row'));
Finder _seg(int row, String part) => find.byKey(Key('referral-seg-$row-$part'));
Finder _out(int row, String part) => find.byKey(Key('referral-out-$row-$part'));

/// El ancho de la pista: es el de la barra más larga (escala común).
double _trackWidth(WidgetTester tester, int row) =>
    tester.getSize(_track(row)).width;

void main() {
  setUpAll(loadRoboto);

  group('tres especialidades con escala común', () {
    // Totales 10, 4 y 3. La barra más larga (10) ocupa todo el ancho.
    final items = [
      _item('Cardiología', 5, 3, 2),
      _item('Pediatría', 2, 1, 1),
      _item('Dermatología', 0, 0, 3),
    ];

    testWidgets(
      'los tramos miden su parte del mayor total, igual en cada fila',
      (tester) async {
        await _pump(tester, items);
        final w = _trackWidth(tester, 0);
        expect(w, closeTo(368, 0.01)); // 400 menos 16 de cada lado
        expect(_trackWidth(tester, 1), closeTo(w, 0.01));
        expect(_trackWidth(tester, 2), closeTo(w, 0.01));

        // Cardiología: 5, 3 y 2 de 10.
        expect(tester.getSize(_seg(0, 'used')).width, closeTo(0.5 * w, 0.5));
        expect(
          tester.getSize(_seg(0, 'available')).width,
          closeTo(0.3 * w, 0.5),
        );
        expect(tester.getSize(_seg(0, 'expired')).width, closeTo(0.2 * w, 0.5));
        // Pediatría: 2, 1 y 1 de 10.
        expect(tester.getSize(_seg(1, 'used')).width, closeTo(0.2 * w, 0.5));
        expect(
          tester.getSize(_seg(1, 'available')).width,
          closeTo(0.1 * w, 0.5),
        );
        expect(tester.getSize(_seg(1, 'expired')).width, closeTo(0.1 * w, 0.5));
        // Dermatología: solo vencidos, 3 de 10.
        expect(tester.getSize(_seg(2, 'expired')).width, closeTo(0.3 * w, 0.5));
      },
    );

    testWidgets('los tramos van en orden, apilados y sin huecos', (
      tester,
    ) async {
      await _pump(tester, items);
      final used = tester.getRect(_seg(0, 'used'));
      final available = tester.getRect(_seg(0, 'available'));
      final expired = tester.getRect(_seg(0, 'expired'));
      final track = tester.getRect(_track(0));

      expect(used.left, closeTo(track.left, 0.01));
      expect(available.left, closeTo(used.right, 0.01));
      expect(expired.left, closeTo(available.right, 0.01));
      expect(expired.right, closeTo(track.right, 0.5)); // 5 + 3 + 2 = 10 de 10
      expect(available.top, used.top);
      expect(expired.top, used.top);
      expect(available.height, used.height);
    });

    testWidgets('los tramos en cero no se dibujan', (tester) async {
      await _pump(tester, items);
      expect(_seg(2, 'used'), findsNothing);
      expect(_seg(2, 'available'), findsNothing);
      expect(_seg(2, 'expired'), findsOneWidget);
    });

    testWidgets('cada tramo lleva su número en texto', (tester) async {
      await _pump(tester, items);
      expect(
        find.descendant(of: _seg(0, 'used'), matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _seg(0, 'available'), matching: find.text('3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _seg(0, 'expired'), matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _seg(2, 'expired'), matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('el orden de las filas es el que llega', (tester) async {
      await _pump(tester, items);
      final names = ['Cardiología', 'Pediatría', 'Dermatología'];
      final tops = [
        for (final name in names) tester.getTopLeft(find.text(name)).dy,
      ];
      expect(tops[0], lessThan(tops[1]));
      expect(tops[1], lessThan(tops[2]));
    });
  });

  group('la escala sale de la suma de los tres tramos', () {
    testWidgets('no de emitidos', (tester) async {
      // Emitidos dice 100, pero los tres tramos suman 10: la barra ocupa todo
      // el ancho y el tramo de 5 mide la mitad.
      await _pump(tester, [_item('Cardiología', 5, 3, 2, issued: 100)]);
      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_seg(0, 'used')).width, closeTo(0.5 * w, 0.5));
      expect(
        tester.getRect(_seg(0, 'expired')).right,
        closeTo(tester.getRect(_track(0)).right, 0.5),
      );
    });

    testWidgets('no de cada fila por separado', (tester) async {
      // La segunda fila suma 4 de 10: su barra llega al 40 %, no al 100 %.
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item('Pediatría', 4, 0, 0),
      ]);
      final w = _trackWidth(tester, 1);
      expect(tester.getSize(_seg(1, 'used')).width, closeTo(0.4 * w, 0.5));
    });
  });

  group('una sola especialidad', () {
    testWidgets('con tres tramos llena el ancho: 4, 0 y 1 de 5', (
      tester,
    ) async {
      await _pump(tester, [_item('Cardiología', 4, 0, 1)]);
      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_seg(0, 'used')).width, closeTo(0.8 * w, 0.5));
      expect(_seg(0, 'available'), findsNothing);
      expect(tester.getSize(_seg(0, 'expired')).width, closeTo(0.2 * w, 0.5));
    });

    testWidgets('con un solo tramo ocupa todo el ancho', (tester) async {
      await _pump(tester, [_item('Cardiología', 0, 7, 0)]);
      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_seg(0, 'available')).width, closeTo(w, 0.5));
      expect(_seg(0, 'used'), findsNothing);
      expect(_seg(0, 'expired'), findsNothing);
    });
  });

  group('cero pases', () {
    testWidgets('una fila sin pases no tiene barra y dice sin pases', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item('Odontología', 0, 0, 0),
      ]);
      expect(_track(1), findsNothing);
      expect(find.byKey(const Key('referral-none-1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('referral-none-1')),
          matching: find.text('sin pases'),
        ),
        findsOneWidget,
      );
      expect(find.text('Odontología'), findsOneWidget);
      // La otra fila sigue con su barra completa.
      expect(_track(0), findsOneWidget);
      expect(find.byKey(const Key('referral-none-0')), findsNothing);
    });

    testWidgets('con todo en cero se muestran igual las filas, sin barra', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Cardiología', 0, 0, 0),
        _item('Odontología', 0, 0, 0),
      ]);
      expect(find.byKey(const Key('referral-chart')), findsOneWidget);
      expect(find.text('Cardiología'), findsOneWidget);
      expect(find.text('Odontología'), findsOneWidget);
      expect(find.text('sin pases'), findsNWidgets(2));
      expect(_track(0), findsNothing);
      expect(_track(1), findsNothing);
      // Sin barras no hay nada que explicar con la leyenda.
      expect(find.byKey(const Key('referral-chart-legend')), findsNothing);
      for (final row in [0, 1]) {
        final data = find.byKey(Key('referral-data-$row'));
        expect(
          find.descendant(of: data, matching: find.text('Emitidos: 0')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: data,
            matching: find.text('Utilización: Sin datos'),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('sin especialidades no hay gráfico', (tester) async {
      await _pump(tester, const []);
      expect(find.byKey(const Key('referral-chart')), findsNothing);
    });
  });

  group('un tramo muy angosto lleva su número fuera de la barra', () {
    testWidgets('1 de 100: el número va debajo, sin tapar a los demás', (
      tester,
    ) async {
      await _pump(tester, [_item('Cardiología', 1, 0, 99)]);
      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_seg(0, 'used')).width, closeTo(0.01 * w, 0.2));

      // El 1 no entra en 3,7 px: sale como "1 utilizado" bajo la barra.
      expect(
        find.descendant(of: _seg(0, 'used'), matching: find.text('1')),
        findsNothing,
      );
      expect(_out(0, 'used'), findsOneWidget);
      expect(
        find.descendant(
          of: _out(0, 'used'),
          matching: find.text('1 utilizado'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(_out(0, 'used')).dy,
        greaterThanOrEqualTo(tester.getRect(_track(0)).bottom),
      );
      // El de 99 sí entra y se queda adentro.
      expect(
        find.descendant(of: _seg(0, 'expired'), matching: find.text('99')),
        findsOneWidget,
      );
      expect(_out(0, 'expired'), findsNothing);
    });

    testWidgets('si todos entran, no hay números afuera', (tester) async {
      await _pump(tester, [_item('Cardiología', 5, 3, 2)]);
      expect(_out(0, 'used'), findsNothing);
      expect(_out(0, 'available'), findsNothing);
      expect(_out(0, 'expired'), findsNothing);
    });

    testWidgets('varios angostos no se superponen entre sí', (tester) async {
      await _pump(tester, [_item('Cardiología', 1, 1, 98)]);
      final used = tester.getRect(_out(0, 'used'));
      final available = tester.getRect(_out(0, 'available'));
      expect(used.overlaps(available), isFalse);
    });
  });

  group('leyenda', () {
    testWidgets('nombra los tres tramos con su patrón', (tester) async {
      await _pump(tester, [_item('Cardiología', 5, 3, 2)]);
      final legend = find.byKey(const Key('referral-chart-legend'));
      expect(legend, findsOneWidget);
      for (final name in ['Utilizados', 'Disponibles', 'Vencidos']) {
        expect(
          find.descendant(of: legend, matching: find.text(name)),
          findsOneWidget,
        );
      }
      for (final part in ['used', 'available', 'expired']) {
        expect(find.byKey(Key('referral-legend-$part')), findsOneWidget);
      }
    });

    testWidgets('el título del gráfico es fijo', (tester) async {
      await _pump(tester, [_item('Cardiología', 5, 3, 2)]);
      expect(
        tester.widget<Text>(find.byKey(const Key('referral-chart-title'))).data,
        'Pases por especialidad de destino',
      );
    });
  });

  group('lector de pantalla', () {
    testWidgets('cada fila dice todo lo de su línea en un solo texto', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2, utilization: '71.43 %'),
        _item('Pediatría', 1, 0, 0, utilization: '100 %'),
        _item('Odontología', 0, 0, 0),
      ]);

      expect(
        find.bySemanticsLabel(
          'Cardiología, 10 emitidos, 5 utilizados, 3 disponibles, '
          '2 vencidos, utilización 71,43 %',
        ),
        findsOneWidget,
      );
      // Con exactamente 1 va en singular.
      expect(
        find.bySemanticsLabel(
          'Pediatría, 1 emitido, 1 utilizado, 0 disponibles, 0 vencidos, '
          'utilización 100 %',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Odontología, sin pases, 0 emitidos, 0 utilizados, '
          '0 disponibles, 0 vencidos, utilización Sin datos',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('lo que se ve queda excluido y no se lee dos veces', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2, utilization: '71.43 %'),
      ]);

      // Los números sueltos de los tramos y los textos de la línea de datos
      // no se leen aparte: todo está en el texto de la fila.
      expect(find.bySemanticsLabel('5'), findsNothing);
      expect(find.bySemanticsLabel('3'), findsNothing);
      expect(find.bySemanticsLabel('2'), findsNothing);
      expect(find.bySemanticsLabel('Emitidos: 10'), findsNothing);
      expect(find.bySemanticsLabel('Utilizados: 5'), findsNothing);
      expect(find.bySemanticsLabel('Utilización: 71.43 %'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Utilización')), findsNothing);
      handle.dispose();
    });
  });

  group('especialidades de pase libre', () {
    // Decisión de producto: una especialidad que no exige pase solo se ve si
    // tiene pases emitidos.
    testWidgets('una de pase libre sin pases no se ve', (tester) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item('Medicina General', 0, 0, 0, requiresReferral: false),
      ]);

      expect(find.text('Cardiología'), findsOneWidget);
      expect(find.text('Medicina General'), findsNothing);
      expect(find.byKey(const Key('referral-row-0')), findsOneWidget);
      expect(find.byKey(const Key('referral-row-1')), findsNothing);
      expect(find.text('sin pases'), findsNothing);
    });

    testWidgets('una de pase libre con pases sí se ve, con su barra', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item('Medicina General', 2, 1, 1, requiresReferral: false),
      ]);

      expect(find.text('Medicina General'), findsOneWidget);
      expect(_track(1), findsOneWidget);
      expect(find.text('Emitidos: 4'), findsOneWidget);
      // Escala común: 4 de 10.
      final w = _trackWidth(tester, 1);
      expect(tester.getSize(_seg(1, 'used')).width, closeTo(0.2 * w, 0.5));
    });

    testWidgets('una que exige pase con cero pases se ve como sin pases', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item('Dermatología', 0, 0, 0),
      ]);

      expect(find.text('Dermatología'), findsOneWidget);
      expect(find.byKey(const Key('referral-none-1')), findsOneWidget);
      expect(_track(1), findsNothing);
    });

    testWidgets('sin el dato requierePase se trata como que sí exige pase', (
      tester,
    ) async {
      // `_item` no lo indica: por defecto exige pase, como pasa con un campo
      // ausente en la respuesta.
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item('Neurología', 0, 0, 0),
      ]);
      expect(find.text('Neurología'), findsOneWidget);
      expect(find.text('sin pases'), findsOneWidget);
    });

    testWidgets('la escala común no cuenta las filas ocultas', (tester) async {
      // La fila oculta tiene emitidos 0 pero tramos que suman 100 (un dato
      // inconsistente a propósito): si entrara en la escala, la barra de
      // Cardiología (10) mediría un 10 % del ancho.
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item(
          'Medicina General',
          100,
          0,
          0,
          issued: 0,
          requiresReferral: false,
        ),
      ]);

      expect(find.text('Medicina General'), findsNothing);
      final w = _trackWidth(tester, 0);
      expect(tester.getSize(_seg(0, 'used')).width, closeTo(0.5 * w, 0.5));
      expect(
        tester.getRect(_seg(0, 'expired')).right,
        closeTo(tester.getRect(_track(0)).right, 0.5),
      );
    });

    testWidgets('las filas visibles conservan su orden y sus claves', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2),
        _item('Medicina General', 0, 0, 0, requiresReferral: false),
        _item('Dermatología', 0, 0, 0),
      ]);

      expect(
        find.descendant(
          of: find.byKey(const Key('referral-row-0')),
          matching: find.text('Cardiología'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('referral-row-1')),
          matching: find.text('Dermatología'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('referral-row-2')), findsNothing);
    });

    testWidgets('si no queda ninguna fila visible no hay gráfico', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Medicina General', 0, 0, 0, requiresReferral: false),
        _item('Pediatría', 0, 0, 0, requiresReferral: false),
      ]);
      expect(find.byKey(const Key('referral-chart')), findsNothing);
    });
  });

  group('la línea de datos de cada fila', () {
    Finder data(int row) => find.byKey(Key('referral-data-$row'));
    Finder inData(int row, String text) =>
        find.descendant(of: data(row), matching: find.text(text));

    testWidgets('trae los cinco datos con el formato de las tarjetas', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2, utilization: '71.43 %'),
      ]);

      for (final text in [
        'Emitidos: 10',
        'Utilizados: 5',
        'Disponibles: 3',
        'Vencidos: 2',
        'Utilización: 71.43 %',
      ]) {
        expect(inData(0, text), findsOneWidget, reason: text);
      }
    });

    testWidgets('van en orden y debajo de la barra', (tester) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2, utilization: '71.43 %'),
      ]);

      final labels = [
        'Emitidos: 10',
        'Utilizados: 5',
        'Disponibles: 3',
        'Vencidos: 2',
        'Utilización: 71.43 %',
      ];
      final positions = [
        for (final label in labels) tester.getTopLeft(find.text(label)),
      ];
      for (var i = 1; i < positions.length; i++) {
        final before = positions[i - 1];
        final after = positions[i];
        // O sigue en el mismo renglón, a la derecha, o baja de renglón.
        expect(
          after.dy > before.dy ||
              (after.dy == before.dy && after.dx > before.dx),
          isTrue,
          reason: labels[i],
        );
      }
      expect(
        positions.first.dy,
        greaterThanOrEqualTo(tester.getRect(_track(0)).bottom),
      );
    });

    testWidgets('emitidos es el que manda el servidor, no la suma', (
      tester,
    ) async {
      await _pump(tester, [_item('Cardiología', 5, 3, 2, issued: 100)]);
      expect(inData(0, 'Emitidos: 100'), findsOneWidget);
      expect(inData(0, 'Emitidos: 10'), findsNothing);
    });

    testWidgets('una utilización sin datos se escribe tal cual', (
      tester,
    ) async {
      await _pump(tester, [_item('Cardiología', 0, 3, 0)]);
      expect(inData(0, 'Utilización: Sin datos'), findsOneWidget);
      expect(inData(0, 'Disponibles: 3'), findsOneWidget);
    });

    testWidgets('una fila sin pases tiene su línea con todo en cero', (
      tester,
    ) async {
      await _pump(tester, [
        _item('Cardiología', 5, 3, 2, utilization: '71.43 %'),
        _item('Odontología', 0, 0, 0),
      ]);

      for (final text in [
        'Emitidos: 0',
        'Utilizados: 0',
        'Disponibles: 0',
        'Vencidos: 0',
        'Utilización: Sin datos',
      ]) {
        expect(inData(1, text), findsOneWidget, reason: text);
      }
      expect(find.text('sin pases'), findsOneWidget);
      // La línea de la fila sin pases va debajo de "sin pases".
      expect(
        tester.getTopLeft(find.text('Emitidos: 0')).dy,
        greaterThan(tester.getTopLeft(find.text('sin pases')).dy),
      );
    });

    testWidgets('con números afuera, la línea va debajo de ellos', (
      tester,
    ) async {
      await _pump(tester, [_item('Cardiología', 1, 0, 99)]);
      expect(
        tester.getTopLeft(data(0)).dy,
        greaterThanOrEqualTo(tester.getRect(_out(0, 'used')).bottom),
      );
    });
  });

  group('a 320 px con el texto al doble', () {
    final items = [
      _item('Otorrinolaringología pediátrica y de cabeza y cuello', 12, 7, 3),
      _item('Medicina física y rehabilitación', 1, 0, 40),
      _item('Odontología', 0, 0, 0),
    ];

    testWidgets('no hay excepciones y todo queda dentro del ancho', (
      tester,
    ) async {
      await _pump(tester, items, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);

      for (final row in [0, 1]) {
        final track = tester.getRect(_track(row));
        expect(track.left, greaterThanOrEqualTo(0));
        expect(track.right, lessThanOrEqualTo(320));
      }
      for (final text in [
        'Otorrinolaringología pediátrica y de cabeza y cuello',
        'Medicina física y rehabilitación',
        'Odontología',
        'sin pases',
      ]) {
        expect(tester.getRect(find.text(text)).right, lessThanOrEqualTo(320));
      }
    });

    testWidgets('con el texto al doble los números que no entran van afuera', (
      tester,
    ) async {
      await _pump(tester, items, width: 320, textScale: 2);
      // 1 de 41 en 288 px son 7 px: el número va debajo de la barra.
      expect(_out(1, 'used'), findsOneWidget);
      final chip = tester.getRect(_out(1, 'used'));
      expect(chip.right, lessThanOrEqualTo(320));
      expect(chip.left, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la línea de datos baja de renglón y no se corta', (
      tester,
    ) async {
      await _pump(
        tester,
        [
          _item(
            'Otorrinolaringología pediátrica y de cabeza y cuello',
            12,
            7,
            3,
            utilization: '80.00 %',
          ),
          _item('Odontología', 0, 0, 0),
        ],
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);

      final expected = {
        0: [
          'Emitidos: 22',
          'Utilizados: 12',
          'Disponibles: 7',
          'Vencidos: 3',
          'Utilización: 80.00 %',
        ],
        1: [
          'Emitidos: 0',
          'Utilizados: 0',
          'Disponibles: 0',
          'Vencidos: 0',
          'Utilización: Sin datos',
        ],
      };
      for (final entry in expected.entries) {
        final tops = <double>{};
        for (final text in entry.value) {
          final rect = tester.getRect(
            find.descendant(
              of: find.byKey(Key('referral-data-${entry.key}')),
              matching: find.text(text),
            ),
          );
          expect(rect.left, greaterThanOrEqualTo(0), reason: text);
          expect(rect.right, lessThanOrEqualTo(320), reason: text);
          tops.add(rect.top);
        }
        // Cinco datos no entran en un renglón de 288 px con el texto al doble.
        expect(tops.length, greaterThan(2), reason: 'fila ${entry.key}');
      }
    });

    testWidgets('la leyenda baja de renglón en vez de salirse', (tester) async {
      await _pump(tester, items, width: 320, textScale: 2);
      final legend = tester.getRect(
        find.byKey(const Key('referral-chart-legend')),
      );
      expect(legend.left, greaterThanOrEqualTo(0));
      expect(legend.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });
}
