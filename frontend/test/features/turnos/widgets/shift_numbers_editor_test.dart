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
}

Future<EditorHarness> pumpEditor(
  WidgetTester tester, {
  List<ShiftNumber> initial = const [],
  bool showEmptyError = false,
}) async {
  tester.view.physicalSize = const Size(1000, 2000);
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
              onChanged: (value) => setState(() => host.numbers = value),
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
}
