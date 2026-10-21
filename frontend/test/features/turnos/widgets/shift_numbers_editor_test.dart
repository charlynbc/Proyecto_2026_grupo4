import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/widgets/shift_numbers_editor.dart';

ShiftNumber n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

/// Monta el editor con estado propio y deja ver el último valor emitido.
class EditorHarness {
  EditorHarness(this.numbers, {this.showEmptyError = false});

  List<ShiftNumber> numbers;
  final bool showEmptyError;

  /// Cuántas veces el editor avisó un cambio de la lista.
  int changes = 0;
}

Future<EditorHarness> pumpEditor(
  WidgetTester tester, {
  List<ShiftNumber> initial = const [],
  bool showEmptyError = false,
  Size size = const Size(1000, 2000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final host = EditorHarness(initial, showEmptyError: showEmptyError);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: ShiftNumbersEditor(
              numbers: host.numbers,
              showEmptyError: host.showEmptyError,
              onChanged: (value) => setState(() {
                host.numbers = value;
                host.changes++;
              }),
            ),
          ),
        ),
      ),
    ),
  );
  return host;
}

Future<void> selectInt(WidgetTester tester, Key key, int value) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  final label = value.toString().padLeft(2, '0');
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Lo que muestran los cuatro desplegables de cada fila, como `HH:MM-HH:MM`,
/// separado por espacios. Es lo que ve la persona, no la lista interna.
String rowsOnScreen(WidgetTester tester) {
  String shown(String key) => tester
      .widget<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
      )
      .data!;
  final rows = <String>[];
  for (var i = 0; find.byKey(Key('number-row-$i')).evaluate().isNotEmpty; i++) {
    rows.add(
      '${shown('number-$i-start-hour')}:${shown('number-$i-start-minute')}-'
      '${shown('number-$i-end-hour')}:${shown('number-$i-end-minute')}',
    );
  }
  return rows.join(' ');
}

/// La lista interna del editor, con el mismo formato que [rowsOnScreen].
String rowsInList(EditorHarness host) => host.numbers
    .map(
      (e) =>
          '${ShiftNumber.formatTime(e.startMinutes)}-'
          '${ShiftNumber.formatTime(e.endMinutes)}',
    )
    .join(' ');

/// La lista y la pantalla muestran [expected], y los números van 1, 2, 3...
/// en ese orden.
Future<void> expectRows(
  WidgetTester tester,
  EditorHarness host,
  String expected,
) async {
  expect(rowsInList(host), expected, reason: 'lista interna');
  expect(rowsOnScreen(tester), expected, reason: 'desplegables de las filas');
  expect(host.numbers.map((e) => e.number), [
    for (var i = 1; i <= host.numbers.length; i++) i,
  ], reason: 'numeración');
}

void main() {
  testWidgets('muestra cada número con su duración calculada', (tester) async {
    await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
    final row = find.byKey(const Key('number-row-0'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('20 min')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Quitar')),
      findsOneWidget,
    );
  });

  testWidgets('avisa cuando no hay ningún número, si se lo piden', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(find.textContaining('al menos un número'), findsNothing);
    await pumpEditor(tester, showEmptyError: true);
    expect(find.textContaining('al menos un número'), findsOneWidget);
  });

  testWidgets('avisa de una duración menor a 10 minutos', (tester) async {
    await pumpEditor(tester, initial: [n(1, '09:00', '09:05')]);
    expect(find.textContaining('entre 10 y 60 minutos'), findsOneWidget);
  });

  testWidgets('avisa de una duración mayor a 60 minutos', (tester) async {
    await pumpEditor(tester, initial: [n(1, '09:00', '10:05')]);
    expect(find.textContaining('entre 10 y 60 minutos'), findsOneWidget);
  });

  testWidgets('avisa de números que se solapan', (tester) async {
    await pumpEditor(
      tester,
      initial: [n(1, '09:00', '09:30'), n(2, '09:20', '09:40')],
    );
    expect(find.textContaining('se solapan'), findsOneWidget);
  });

  testWidgets('no avisa nada con números válidos y con huecos', (tester) async {
    await pumpEditor(
      tester,
      initial: [n(1, '09:00', '09:20'), n(2, '10:00', '10:30')],
    );
    expect(find.textContaining('se solapan'), findsNothing);
    expect(find.textContaining('entre 10 y 60'), findsNothing);
  });

  testWidgets('el selector de minutos solo ofrece múltiplos de 5', (
    tester,
  ) async {
    await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
    final dropdown = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: find.byKey(const Key('number-0-start-minute')),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    final values = dropdown.items!.map((item) => item.value).toList();
    expect(values, [for (var m = 0; m < 60; m += 5) m]);
    expect(values.length, 12);
  });

  testWidgets('editar un minuto recalcula la duración y valida', (
    tester,
  ) async {
    final host = await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
    await selectInt(tester, const Key('number-0-start-minute'), 15);
    expect(host.numbers.single.startMinutes, ShiftNumber.parseTime('09:15'));
    expect(find.text('5 min'), findsOneWidget);
    expect(find.textContaining('entre 10 y 60 minutos'), findsOneWidget);
  });

  testWidgets('agregar un número lo suma a continuación del último', (
    tester,
  ) async {
    final host = await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
    await tester.tap(find.text('Agregar número'));
    await tester.pumpAndSettle();
    expect(host.numbers.length, 2);
    expect(host.numbers.last.startMinutes, ShiftNumber.parseTime('09:20'));
    expect(host.numbers.last.duration, 20);
  });

  testWidgets('quitar un número lo saca y renumera', (tester) async {
    final host = await pumpEditor(
      tester,
      initial: [n(1, '09:00', '09:20'), n(2, '09:20', '09:40')],
    );
    await tester.tap(find.text('Quitar').first);
    await tester.pumpAndSettle();
    expect(host.numbers.length, 1);
    expect(host.numbers.single.number, 1);
    expect(host.numbers.single.startMinutes, ShiftNumber.parseTime('09:20'));
  });

  testWidgets('al quitar un número, los selectores muestran la hora nueva', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      initial: [n(1, '09:00', '09:20'), n(2, '10:00', '10:30')],
    );
    await tester.tap(find.text('Quitar').first);
    await tester.pumpAndSettle();

    String shown(String key) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Text),
          ),
        )
        .data!;

    expect(shown('number-0-start-hour'), '10');
    expect(shown('number-0-start-minute'), '00');
    expect(shown('number-0-end-hour'), '10');
    expect(shown('number-0-end-minute'), '30');
  });

  testWidgets('genera varios números seguidos con la duración elegida', (
    tester,
  ) async {
    final host = await pumpEditor(tester);
    // Por defecto: de 09:00 a 10:00 cada 20 minutos.
    await tester.tap(find.text('Generar números'));
    await tester.pumpAndSettle();
    expect(host.numbers.map((e) => e.toJson()).toList(), [
      {'numero': 1, 'horaInicio': '09:00', 'horaFin': '09:20'},
      {'numero': 2, 'horaInicio': '09:20', 'horaFin': '09:40'},
      {'numero': 3, 'horaInicio': '09:40', 'horaFin': '10:00'},
    ]);
  });

  testWidgets('la duración del generador se elige de una lista de 5 en 5', (
    tester,
  ) async {
    final host = await pumpEditor(tester);
    await tester.tap(find.byKey(const Key('generator-duration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generar números'));
    await tester.pumpAndSettle();
    expect(host.numbers.length, 2);
    expect(host.numbers.every((e) => e.duration == 30), isTrue);
  });

  testWidgets('avisa cuántos minutos sobraron al generar', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byKey(const Key('generator-duration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25 min').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generar números'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sobraron 10 minutos'), findsOneWidget);
  });

  // Decisión: "Generar números" omite solo los duplicados totales. Un número
  // generado se omite si su intervalo queda completo dentro de uno ya cargado
  // (idéntico o contenido). Los solapamientos parciales y el caso en que el
  // generado contiene a uno existente pasan, y los avisa la validación de
  // siempre. El rango por defecto del generador es 09:00 a 10:00 cada 20 min:
  // 09:00-09:20, 09:20-09:40 y 09:40-10:00.
  group('generar números no repite los que ya están cargados', () {
    String times(List<ShiftNumber> numbers) => numbers
        .map(
          (e) =>
              '${ShiftNumber.formatTime(e.startMinutes)}-'
              '${ShiftNumber.formatTime(e.endMinutes)}',
        )
        .join(' ');

    const omittedOne = 'Se omitió 1 número que ya estaba cargado.';
    const omittedAll =
        'Esos números ya estaban cargados: no se agregó ninguno.';

    Future<void> generate(WidgetTester tester) async {
      await tester.tap(find.text('Generar números'));
      await tester.pumpAndSettle();
    }

    testWidgets('un número idéntico a uno cargado se omite y se avisa', (
      tester,
    ) async {
      final host = await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);

      await generate(tester);

      expect(times(host.numbers), '09:00-09:20 09:20-09:40 09:40-10:00');
      expect(host.numbers.map((e) => e.number), [1, 2, 3]);
      expect(find.text(omittedOne), findsOneWidget);
      expect(find.textContaining('se solapan'), findsNothing);
    });

    testWidgets('un número contenido en uno cargado se omite, y se cuentan', (
      tester,
    ) async {
      // 09:00-09:40 contiene a 09:00-09:20 y a 09:20-09:40.
      final host = await pumpEditor(tester, initial: [n(1, '09:00', '09:40')]);

      await generate(tester);

      expect(times(host.numbers), '09:00-09:40 09:40-10:00');
      expect(
        find.text('Se omitieron 2 números que ya estaban cargados.'),
        findsOneWidget,
      );
      expect(find.text(omittedOne), findsNothing);
    });

    testWidgets('un solapamiento parcial pasa y lo avisa la validación', (
      tester,
    ) async {
      // 09:10-09:30 pisa una parte de 09:00-09:20 y otra de 09:20-09:40.
      final host = await pumpEditor(tester, initial: [n(1, '09:10', '09:30')]);

      await generate(tester);

      expect(host.numbers.length, 4);
      expect(find.textContaining('se solapan'), findsWidgets);
      expect(find.textContaining('Se omit'), findsNothing);
    });

    testWidgets('si el generado contiene a uno cargado, pasa', (tester) async {
      // 09:05-09:15 queda dentro de 09:00-09:20, pero no al revés.
      final host = await pumpEditor(tester, initial: [n(1, '09:05', '09:15')]);

      await generate(tester);

      // Ordenados por hora de inicio: 09:00, 09:05, 09:20 y 09:40. El cargado
      // (09:05) queda segundo, entre 09:00-09:20 y 09:20-09:40.
      await expectRows(
        tester,
        host,
        '09:00-09:20 09:05-09:15 09:20-09:40 09:40-10:00',
      );
      expect(find.textContaining('se solapan'), findsWidgets);
      expect(find.textContaining('Se omit'), findsNothing);
    });

    testWidgets('si se omiten todos, la lista no cambia y se avisa', (
      tester,
    ) async {
      final initial = [
        n(1, '09:00', '09:20'),
        n(2, '09:20', '09:40'),
        n(3, '09:40', '10:00'),
      ];
      final host = await pumpEditor(tester, initial: initial);

      await generate(tester);

      expect(host.changes, 0, reason: 'no se agregó nada: no hubo cambio');
      expect(identical(host.numbers, initial), isTrue);
      expect(times(host.numbers), '09:00-09:20 09:20-09:40 09:40-10:00');
      expect(find.text(omittedAll), findsOneWidget);
    });

    testWidgets('apretar dos veces seguidas el mismo rango no cambia el '
        'resultado', (tester) async {
      final host = await pumpEditor(tester);

      await generate(tester);
      final afterFirst = times(host.numbers);
      expect(afterFirst, '09:00-09:20 09:20-09:40 09:40-10:00');
      expect(find.textContaining('Se omit'), findsNothing);
      final changesAfterFirst = host.changes;

      await generate(tester);

      expect(times(host.numbers), afterFirst);
      expect(host.numbers.length, 3);
      expect(host.changes, changesAfterFirst);
      expect(find.text(omittedAll), findsOneWidget);
    });

    testWidgets('el aviso se va al generar algo que sí es nuevo', (
      tester,
    ) async {
      await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
      await generate(tester);
      expect(find.text(omittedOne), findsOneWidget);

      // Otro rango, sin nada repetido.
      await tester.tap(find.byKey(const Key('generator-start-hour')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('11').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('generator-end-hour')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12').last);
      await tester.pumpAndSettle();
      await generate(tester);

      expect(find.textContaining('Se omit'), findsNothing);
      expect(find.text(omittedAll), findsNothing);
    });

    testWidgets('el aviso de lo omitido convive con el de los minutos que '
        'sobraron', (tester) async {
      // Cada 25 minutos: 09:00-09:25 y 09:25-09:50, sobran 10.
      final host = await pumpEditor(tester, initial: [n(1, '09:00', '09:25')]);
      await tester.tap(find.byKey(const Key('generator-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('25 min').last);
      await tester.pumpAndSettle();

      await generate(tester);

      expect(times(host.numbers), '09:00-09:25 09:25-09:50');
      expect(find.text(omittedOne), findsOneWidget);
      expect(find.textContaining('Sobraron 10 minutos'), findsOneWidget);
    });
  });

  // Decisión: al agregar o generar, la lista queda ordenada por hora de inicio
  // (con el mismo inicio, por hora de fin) y renumerada 1, 2, 3... en ese
  // orden. "Agregar número" parte del número que termina más tarde, no del
  // último de la lista. Editar una hora no reordena. En todos se mira lo que
  // muestran los desplegables de cada fila, no solo la lista interna.
  group('el orden por hora al agregar y al generar', () {
    Future<void> setDuration(WidgetTester tester, int minutes) async {
      await tester.tap(find.byKey(const Key('generator-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$minutes min').last);
      await tester.pumpAndSettle();
    }

    Future<void> add(WidgetTester tester) async {
      await tester.tap(find.text('Agregar número'));
      await tester.pumpAndSettle();
    }

    Future<void> generate(WidgetTester tester) async {
      await tester.tap(find.text('Generar números'));
      await tester.pumpAndSettle();
    }

    testWidgets('agregar parte del número que termina más tarde, no del '
        'último de la lista', (tester) async {
      // El último de la lista (08:00-08:40) no es el que termina más tarde
      // (09:00-09:20). Con 30 minutos, desde 08:40 pisaría 09:00-09:20.
      final host = await pumpEditor(
        tester,
        initial: [n(1, '09:00', '09:20'), n(2, '08:00', '08:40')],
      );
      await setDuration(tester, 30);

      await add(tester);

      await expectRows(tester, host, '08:00-08:40 09:00-09:20 09:20-09:50');
      expect(find.textContaining('se solapan'), findsNothing);
    });

    testWidgets('agregar ordena y renumera lo que ya estaba, aunque el nuevo '
        'caiga al final', (tester) async {
      // Con 20 minutos, el nuevo es 09:20-09:40 (el máximo fin es 09:20).
      final host = await pumpEditor(
        tester,
        initial: [n(1, '09:00', '09:20'), n(2, '08:00', '08:20')],
      );

      await add(tester);

      await expectRows(tester, host, '08:00-08:20 09:00-09:20 09:20-09:40');
    });

    testWidgets('generar inserta por hora, no al final', (tester) async {
      // El generador por defecto va de 09:00 a 10:00 cada 20 minutos.
      final host = await pumpEditor(tester, initial: [n(1, '10:00', '10:20')]);

      await generate(tester);

      await expectRows(
        tester,
        host,
        '09:00-09:20 09:20-09:40 09:40-10:00 10:00-10:20',
      );
    });

    testWidgets('generar ordena también lo desordenado que ya había', (
      tester,
    ) async {
      final host = await pumpEditor(
        tester,
        initial: [n(1, '11:00', '11:20'), n(2, '10:00', '10:20')],
      );

      await generate(tester);

      await expectRows(
        tester,
        host,
        '09:00-09:20 09:20-09:40 09:40-10:00 10:00-10:20 11:00-11:20',
      );
    });

    testWidgets('editar una hora no reordena la lista', (tester) async {
      final host = await pumpEditor(
        tester,
        initial: [n(1, '09:00', '09:20'), n(2, '10:00', '10:30')],
      );

      // La segunda fila pasa a empezar a las 08:00, antes que la primera.
      await selectInt(tester, const Key('number-1-start-hour'), 8);

      expect(rowsInList(host), '09:00-09:20 08:00-10:30');
      expect(rowsOnScreen(tester), '09:00-09:20 08:00-10:30');
    });
  });

  // Decisión: "Generar números" con la hora "Hasta" menor o igual que "Desde" no
  // agrega nada y lo avisa, en color de error, dentro de la tarjeta del
  // generador. El aviso vive como el de "Agregar número": se limpia con la
  // siguiente acción del editor y al cambiar "Desde", "Hasta" o la duración.
  // Los avisos de "Sobraron" y "Se omitieron" se reemplazan al generar, pero
  // no se limpian al cambiar el rango.
  group('generar con la hora Hasta menor o igual que Desde', () {
    const rangeMessage =
        'La hora "Hasta" tiene que ser posterior a la hora "Desde": '
        'no se agregó ningún número.';
    final rangeNotice = find.text(rangeMessage);
    String noFit(int minutes) =>
        'No entra otro número de $minutes minutos antes de las 23:55.';

    Future<void> setDuration(WidgetTester tester, int minutes) async {
      await tester.tap(find.byKey(const Key('generator-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$minutes min').last);
      await tester.pumpAndSettle();
    }

    Future<void> generate(WidgetTester tester) async {
      await tester.tap(find.text('Generar números'));
      await tester.pumpAndSettle();
    }

    Future<void> add(WidgetTester tester) async {
      await tester.tap(find.text('Agregar número'));
      await tester.pumpAndSettle();
    }

    /// El generador arranca de 09:00 a 10:00: "Hasta" a las 08:00 queda antes.
    Future<void> generateWithHastaBefore(WidgetTester tester) async {
      await selectInt(tester, const Key('generator-end-hour'), 8);
      await generate(tester);
    }

    testWidgets('con Hasta igual a Desde avisa y no agrega nada', (
      tester,
    ) async {
      final host = await pumpEditor(tester);
      await selectInt(tester, const Key('generator-end-hour'), 9);

      await generate(tester);

      expect(rangeNotice, findsOneWidget);
      expect(host.numbers, isEmpty);
    });

    testWidgets('con Hasta menor que Desde avisa y no agrega nada', (
      tester,
    ) async {
      final host = await pumpEditor(tester);

      await generateWithHastaBefore(tester);

      expect(rangeNotice, findsOneWidget);
      expect(host.numbers, isEmpty);
    });

    testWidgets('la lista queda idéntica y no hay cambios', (tester) async {
      final initial = [n(1, '09:00', '09:20'), n(2, '09:20', '09:40')];
      final host = await pumpEditor(tester, initial: initial);

      await generateWithHastaBefore(tester);

      expect(rangeNotice, findsOneWidget);
      expect(host.changes, 0);
      expect(identical(host.numbers, initial), isTrue);
    });

    testWidgets('el aviso va en el color de error del tema', (tester) async {
      await pumpEditor(tester);

      await generateWithHastaBefore(tester);

      expect(rangeNotice, findsOneWidget);
      final error = Theme.of(tester.element(rangeNotice)).colorScheme.error;
      expect(tester.widget<Text>(rangeNotice).style?.color, error);
    });

    testWidgets('reemplaza los avisos de la tanda anterior', (tester) async {
      // Cada 25 minutos: 09:00-09:25 ya estaba (se omite) y sobran 10 minutos.
      await pumpEditor(tester, initial: [n(1, '09:00', '09:25')]);
      await setDuration(tester, 25);
      await generate(tester);
      expect(
        find.text('Se omitió 1 número que ya estaba cargado.'),
        findsOneWidget,
      );
      expect(find.textContaining('Sobraron 10 minutos'), findsOneWidget);

      await generateWithHastaBefore(tester);

      expect(rangeNotice, findsOneWidget);
      expect(find.textContaining('Se omit'), findsNothing);
      expect(find.textContaining('Sobraron'), findsNothing);
    });

    testWidgets('limpia el aviso de agregar: nunca están los dos a la vez', (
      tester,
    ) async {
      await pumpEditor(tester, initial: [n(1, '23:25', '23:50')]);
      await setDuration(tester, 25);
      await add(tester);
      expect(find.text(noFit(25)), findsOneWidget);

      await generateWithHastaBefore(tester);

      expect(rangeNotice, findsOneWidget);
      expect(find.text(noFit(25)), findsNothing);
    });

    testWidgets('agregar sin lugar reemplaza el aviso del rango: nunca están '
        'los dos a la vez', (tester) async {
      await pumpEditor(tester, initial: [n(1, '23:25', '23:50')]);
      // La duración va primero: cambiarla después limpiaría el aviso del rango.
      await setDuration(tester, 25);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await add(tester);

      expect(find.text(noFit(25)), findsOneWidget);
      expect(rangeNotice, findsNothing);
    });

    // Cambiar un selector ya limpia el aviso, así que "generar con un rango
    // válido" no se puede aislar: se prueba el recorrido completo.
    testWidgets('corregido el rango, generar agrega los números y el aviso no '
        'vuelve', (tester) async {
      final host = await pumpEditor(tester);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      // Hasta a las 11:00: de 09:00 a 11:00 cada 20 minutos son 6 números.
      await selectInt(tester, const Key('generator-end-hour'), 11);
      await generate(tester);

      expect(rangeNotice, findsNothing);
      expect(host.numbers.length, 6);
    });

    testWidgets('se limpia en la siguiente acción: agregar', (tester) async {
      final host = await pumpEditor(tester);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await add(tester);

      expect(rangeNotice, findsNothing);
      expect(host.numbers.length, 1);
    });

    testWidgets('se limpia en la siguiente acción: quitar', (tester) async {
      await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(rangeNotice, findsNothing);
    });

    testWidgets('se limpia en la siguiente acción: ordenar', (tester) async {
      await pumpEditor(
        tester,
        initial: [n(1, '10:00', '10:20'), n(2, '09:00', '09:20')],
      );
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await tester.tap(find.text('Ordenar'));
      await tester.pumpAndSettle();

      expect(rangeNotice, findsNothing);
    });

    testWidgets('se limpia en la siguiente acción: editar una hora', (
      tester,
    ) async {
      await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await selectInt(tester, const Key('number-0-start-minute'), 10);

      expect(rangeNotice, findsNothing);
    });

    testWidgets('se limpia al cambiar Desde', (tester) async {
      await pumpEditor(tester);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await selectInt(tester, const Key('generator-start-hour'), 7);

      expect(rangeNotice, findsNothing);
    });

    testWidgets('se limpia al cambiar Hasta', (tester) async {
      await pumpEditor(tester);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await selectInt(tester, const Key('generator-end-hour'), 7);

      expect(rangeNotice, findsNothing);
    });

    testWidgets('se limpia al cambiar la duración', (tester) async {
      await pumpEditor(tester);
      await generateWithHastaBefore(tester);
      expect(rangeNotice, findsOneWidget);

      await setDuration(tester, 30);

      expect(rangeNotice, findsNothing);
    });

    testWidgets('Hasta posterior a Desde pero menor que la duración avisa los '
        'minutos que sobran, no este aviso', (tester) async {
      await pumpEditor(tester);
      // Hasta 09:10 con Desde 09:00 y 20 minutos: no entra ningún número.
      await selectInt(tester, const Key('generator-end-hour'), 9);
      await selectInt(tester, const Key('generator-end-minute'), 10);

      await generate(tester);

      expect(find.textContaining('Sobraron 10 minutos'), findsOneWidget);
      expect(rangeNotice, findsNothing);
    });

    testWidgets('con un rango válido no aparece', (tester) async {
      final host = await pumpEditor(tester);

      await generate(tester);

      expect(rangeNotice, findsNothing);
      expect(host.numbers.length, 3);
    });

    testWidgets('en 400 × 600 el aviso se alcanza y no desborda', (
      tester,
    ) async {
      // Se arma en una ventana alta (a 600 el menú de un desplegable no entra)
      // y recién después se achica.
      await pumpEditor(tester, size: const Size(400, 2000));
      await selectInt(tester, const Key('generator-end-hour'), 8);
      tester.view.physicalSize = const Size(400, 600);
      await tester.pumpAndSettle();

      final button = find.text('Generar números');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(rangeNotice, findsOneWidget);
      await tester.ensureVisible(rangeNotice);
      await tester.pumpAndSettle();
      final rect = tester.getRect(rangeNotice);
      expect(rect.right, lessThanOrEqualTo(400));
      expect(rect.bottom, lessThanOrEqualTo(600));
      expect(tester.takeException(), isNull);
    });
  });

  // Decisión: si algún número empieza antes que el anterior (se compara solo el
  // inicio), el editor lo avisa y ofrece "Ordenar". El aviso no es un error y
  // no impide guardar. Agregar y generar ya dejan la lista ordenada, y editar
  // una hora no la reordena.
  group('aviso de números fuera de orden', () {
    final notice = find.byKey(const Key('unsorted-notice'));
    final noticeText = find.text('Los números no están en orden por hora.');
    final sortButton = find.text('Ordenar');

    final unsorted = [n(1, '10:00', '10:20'), n(2, '09:00', '09:20')];

    testWidgets('aparece cuando un número empieza antes que el anterior', (
      tester,
    ) async {
      await pumpEditor(tester, initial: unsorted);

      expect(notice, findsOneWidget);
      expect(noticeText, findsOneWidget);
      expect(sortButton, findsOneWidget);
    });

    testWidgets('no aparece con la lista vacía', (tester) async {
      await pumpEditor(tester);

      expect(notice, findsNothing);
      expect(sortButton, findsNothing);
    });

    testWidgets('no aparece con un solo número', (tester) async {
      await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);

      expect(notice, findsNothing);
      expect(sortButton, findsNothing);
    });

    testWidgets('no aparece con la lista ordenada', (tester) async {
      await pumpEditor(
        tester,
        initial: [n(1, '09:00', '09:20'), n(2, '10:00', '10:20')],
      );

      expect(notice, findsNothing);
      expect(sortButton, findsNothing);
    });

    testWidgets('con el mismo inicio no cuenta, aunque los fines estén al '
        'revés', (tester) async {
      await pumpEditor(
        tester,
        initial: [n(1, '09:00', '09:40'), n(2, '09:00', '09:20')],
      );

      expect(notice, findsNothing);
    });

    testWidgets('después de agregar un número desaparece, porque la lista '
        'queda ordenada', (tester) async {
      await pumpEditor(tester, initial: unsorted);
      expect(notice, findsOneWidget);

      await tester.tap(find.text('Agregar número'));
      await tester.pumpAndSettle();

      expect(notice, findsNothing);
    });

    testWidgets('después de generar números desaparece, porque la lista '
        'queda ordenada', (tester) async {
      await pumpEditor(
        tester,
        initial: [n(1, '11:00', '11:20'), n(2, '10:00', '10:20')],
      );
      expect(notice, findsOneWidget);

      await tester.tap(find.text('Generar números'));
      await tester.pumpAndSettle();

      expect(notice, findsNothing);
    });

    testWidgets('"Ordenar" ordena, renumera 1..n y hace desaparecer el '
        'aviso', (tester) async {
      final host = await pumpEditor(tester, initial: unsorted);
      expect(notice, findsOneWidget);

      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      await expectRows(tester, host, '09:00-09:20 10:00-10:20');
      expect(notice, findsNothing);
      expect(sortButton, findsNothing);
    });

    testWidgets('editar una hora no reordena y deja el aviso si queda '
        'desordenada', (tester) async {
      final host = await pumpEditor(
        tester,
        initial: [n(1, '09:00', '09:20'), n(2, '10:00', '10:30')],
      );
      expect(notice, findsNothing);

      // La segunda fila pasa a empezar a las 08:00, antes que la primera.
      await selectInt(tester, const Key('number-1-start-hour'), 8);

      expect(rowsInList(host), '09:00-09:20 08:00-10:30');
      expect(rowsOnScreen(tester), '09:00-09:20 08:00-10:30');
      expect(notice, findsOneWidget);
    });

    testWidgets('editar una hora hasta dejarla en orden hace desaparecer el '
        'aviso', (tester) async {
      await pumpEditor(tester, initial: unsorted);
      expect(notice, findsOneWidget);

      // La primera fila pasa a empezar a las 08:00, antes que la segunda.
      await selectInt(tester, const Key('number-0-start-hour'), 8);

      expect(notice, findsNothing);
    });

    testWidgets('quitar el número que desordena hace desaparecer el aviso', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        initial: [
          n(1, '10:00', '10:20'),
          n(2, '09:00', '09:20'),
          n(3, '11:00', '11:20'),
        ],
      );
      expect(notice, findsOneWidget);

      await tester.tap(find.text('Quitar').at(1));
      await tester.pumpAndSettle();

      expect(notice, findsNothing);
    });

    testWidgets('en 400 × 600 se alcanza, no desborda y funciona', (
      tester,
    ) async {
      final host = await pumpEditor(
        tester,
        initial: unsorted,
        size: const Size(400, 600),
      );

      expect(sortButton, findsOneWidget);
      await tester.ensureVisible(sortButton);
      await tester.pumpAndSettle();

      final rect = tester.getRect(sortButton);
      expect(rect.right, lessThanOrEqualTo(400));
      expect(rect.bottom, lessThanOrEqualTo(600));
      expect(tester.takeException(), isNull);

      await tester.tap(sortButton);
      await tester.pumpAndSettle();
      expect(rowsInList(host), '09:00-09:20 10:00-10:20');
      expect(notice, findsNothing);
    });
  });

  // Decisión: "Agregar número" usa lo que tenga el generador en ese momento.
  // Con la lista vacía arranca en la hora de inicio del generador; con
  // números cargados, donde termina el último. Dura la duración elegida en el
  // generador. No lo limita la hora final del generador. Si el número
  // terminaría después de las 23:55 (el máximo del selector), no se agrega.
  group('agregar número usa la configuración vigente del generador', () {
    String time(int minutes) => ShiftNumber.formatTime(minutes);

    Future<void> setDuration(WidgetTester tester, int minutes) async {
      await tester.tap(find.byKey(const Key('generator-duration')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$minutes min').last);
      await tester.pumpAndSettle();
    }

    Future<void> add(WidgetTester tester) async {
      await tester.tap(find.text('Agregar número'));
      await tester.pumpAndSettle();
    }

    String noFit(int minutes) =>
        'No entra otro número de $minutes minutos antes de las 23:55.';

    testWidgets(
      'con los valores iniciales del generador, el resultado es el de '
      'siempre: 09:00 a 09:20',
      (tester) async {
        final host = await pumpEditor(tester);

        await add(tester);

        expect(time(host.numbers.single.startMinutes), '09:00');
        expect(time(host.numbers.single.endMinutes), '09:20');
      },
    );

    testWidgets(
      'con la lista vacía arranca en la hora de inicio del generador',
      (tester) async {
        final host = await pumpEditor(tester);
        await selectInt(tester, const Key('generator-start-hour'), 11);
        await selectInt(tester, const Key('generator-start-minute'), 30);

        await add(tester);

        expect(time(host.numbers.single.startMinutes), '11:30');
        expect(time(host.numbers.single.endMinutes), '11:50');
      },
    );

    testWidgets('con la lista vacía dura lo que dice el generador', (
      tester,
    ) async {
      final host = await pumpEditor(tester);
      await setDuration(tester, 30);

      await add(tester);

      expect(time(host.numbers.single.startMinutes), '09:00');
      expect(time(host.numbers.single.endMinutes), '09:30');
    });

    testWidgets('con un número cargado arranca donde terminó y dura lo del '
        'generador', (tester) async {
      final host = await pumpEditor(tester, initial: [n(1, '09:00', '09:20')]);
      await setDuration(tester, 25);

      await add(tester);

      expect(host.numbers.length, 2);
      expect(time(host.numbers.last.startMinutes), '09:20');
      expect(time(host.numbers.last.endMinutes), '09:45');
      expect(host.numbers.last.number, 2);
    });

    testWidgets('con un número cargado no lo limita la hora final del '
        'generador', (tester) async {
      // El generador termina a las 10:00; el número que se agrega, después.
      final host = await pumpEditor(tester, initial: [n(1, '10:00', '10:20')]);

      await add(tester);

      expect(time(host.numbers.last.startMinutes), '10:20');
      expect(time(host.numbers.last.endMinutes), '10:40');
    });

    testWidgets('si termina después de las 23:55, no agrega, no hay cambio y '
        'avisa', (tester) async {
      // 23:50 + 25 minutos = 24:15.
      final initial = [n(1, '23:25', '23:50')];
      final host = await pumpEditor(tester, initial: initial);
      await setDuration(tester, 25);

      await add(tester);

      expect(host.changes, 0);
      expect(identical(host.numbers, initial), isTrue);
      expect(find.text(noFit(25)), findsOneWidget);
    });

    testWidgets('con la lista vacía y el generador en 23:00 de 60 minutos, no '
        'agrega y avisa', (tester) async {
      // 23:00 + 60 minutos = 24:00.
      final host = await pumpEditor(tester);
      await selectInt(tester, const Key('generator-start-hour'), 23);
      await setDuration(tester, 60);

      await add(tester);

      expect(host.numbers, isEmpty);
      expect(host.changes, 0);
      expect(find.text(noFit(60)), findsOneWidget);
    });

    testWidgets('un número que termina justo a las 23:55 sí entra', (
      tester,
    ) async {
      final host = await pumpEditor(tester, initial: [n(1, '23:00', '23:30')]);
      await setDuration(tester, 25);

      await add(tester);

      expect(time(host.numbers.last.startMinutes), '23:30');
      expect(time(host.numbers.last.endMinutes), '23:55');
      expect(find.textContaining('No entra'), findsNothing);
    });

    testWidgets('con la lista vacía, uno que termina justo a las 23:55 también '
        'entra', (tester) async {
      final host = await pumpEditor(tester);
      await selectInt(tester, const Key('generator-start-hour'), 23);
      await selectInt(tester, const Key('generator-start-minute'), 30);
      await setDuration(tester, 25);

      await add(tester);

      expect(time(host.numbers.single.startMinutes), '23:30');
      expect(time(host.numbers.single.endMinutes), '23:55');
    });

    testWidgets('un minuto más y no entra: 23:30 con 30 minutos termina a las '
        '24:00', (tester) async {
      final host = await pumpEditor(tester);
      await selectInt(tester, const Key('generator-start-hour'), 23);
      await selectInt(tester, const Key('generator-start-minute'), 30);
      await setDuration(tester, 30);

      await add(tester);

      expect(host.numbers, isEmpty);
      expect(find.text(noFit(30)), findsOneWidget);
    });

    testWidgets('el aviso se limpia en la siguiente acción: agregar', (
      tester,
    ) async {
      final host = await pumpEditor(tester, initial: [n(1, '23:00', '23:30')]);
      await setDuration(tester, 30);
      await add(tester);
      expect(find.text(noFit(30)), findsOneWidget);

      await setDuration(tester, 25);
      await add(tester);

      expect(find.textContaining('No entra'), findsNothing);
      expect(host.numbers.length, 2);
    });

    testWidgets('el aviso se limpia en la siguiente acción: quitar', (
      tester,
    ) async {
      await pumpEditor(tester, initial: [n(1, '23:25', '23:50')]);
      await setDuration(tester, 25);
      await add(tester);
      expect(find.text(noFit(25)), findsOneWidget);

      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No entra'), findsNothing);
    });

    testWidgets('el aviso se limpia en la siguiente acción: generar', (
      tester,
    ) async {
      await pumpEditor(tester, initial: [n(1, '23:25', '23:50')]);
      await setDuration(tester, 25);
      await add(tester);
      expect(find.text(noFit(25)), findsOneWidget);

      await tester.tap(find.text('Generar números'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No entra'), findsNothing);
    });

    testWidgets('el aviso se limpia en la siguiente acción: editar una hora', (
      tester,
    ) async {
      await pumpEditor(tester, initial: [n(1, '23:25', '23:50')]);
      await setDuration(tester, 25);
      await add(tester);
      expect(find.text(noFit(25)), findsOneWidget);

      await selectInt(tester, const Key('number-0-start-minute'), 20);

      expect(find.textContaining('No entra'), findsNothing);
    });

    testWidgets('el aviso se limpia en la siguiente acción: ordenar', (
      tester,
    ) async {
      // Desordenada (23:25 antes que 09:20) y sin lugar para otro número: el
      // intento de agregar no la ordena y deja los dos avisos a la vez.
      final host = await pumpEditor(
        tester,
        initial: [n(1, '23:25', '23:50'), n(2, '09:20', '09:40')],
      );
      await setDuration(tester, 25);
      await add(tester);
      final orderNotice = find.byKey(const Key('unsorted-notice'));
      expect(find.text(noFit(25)), findsOneWidget);
      expect(orderNotice, findsOneWidget);

      await tester.tap(find.text('Ordenar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No entra'), findsNothing);
      await expectRows(tester, host, '09:20-09:40 23:25-23:50');
      expect(orderNotice, findsNothing);
    });

    testWidgets('si se repite el intento, el aviso sigue una sola vez', (
      tester,
    ) async {
      await pumpEditor(tester, initial: [n(1, '23:25', '23:50')]);
      await setDuration(tester, 25);

      await add(tester);
      await add(tester);

      expect(find.text(noFit(25)), findsOneWidget);
    });
  });
}
