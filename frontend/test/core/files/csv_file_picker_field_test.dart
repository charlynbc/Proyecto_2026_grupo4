import 'dart:typed_data';

import 'package:agenda_medica/core/files/csv_file_picker.dart';
import 'package:agenda_medica/core/files/csv_file_picker_field.dart';
import 'package:agenda_medica/core/files/picked_csv_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

class _FakePicker implements CsvFilePicker {
  _FakePicker(this.result);

  /// Lo que devuelve `pick`: un archivo, `null` (canceló) o una excepción.
  Object? result;

  @override
  Future<PickedCsvFile?> pick() async {
    final r = result;
    if (r is Exception) throw r;
    return r as PickedCsvFile?;
  }
}

PickedCsvFile _file(String name, int size) =>
    PickedCsvFile(name: name, bytes: Uint8List(size));

void main() {
  late List<PickedCsvFile?> changes;

  /// Monta el campo con el estado que tendría la pantalla que lo usa.
  Future<void> pump(
    WidgetTester tester,
    _FakePicker picker, {
    PickedCsvFile? initial,
    Size size = const Size(800, 600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    changes = [];
    var value = initial;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [csvFilePickerProvider.overrideWithValue(picker)],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CsvFilePickerField(
                value: value,
                onChanged: (file) {
                  changes.add(file);
                  setState(() => value = file);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> tapPick(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('csv-pick-button')));
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data!;

  testWidgets('sin archivo muestra el botón Elegir archivo CSV', (
    tester,
  ) async {
    await pump(tester, _FakePicker(null));

    expect(find.text('Elegir archivo CSV'), findsOneWidget);
    expect(find.byKey(const Key('csv-file-name')), findsNothing);
    expect(find.byKey(const Key('csv-file-error')), findsNothing);
  });

  testWidgets('elegir un archivo muestra el nombre y el tamaño', (
    tester,
  ) async {
    await pump(tester, _FakePicker(_file('especialidades.csv', 1536)));

    await tapPick(tester);

    expect(textOf(tester, const Key('csv-file-name')), 'especialidades.csv');
    expect(find.text('1,5 KB'), findsOneWidget);
    expect(changes, hasLength(1));
    expect(changes.single!.name, 'especialidades.csv');
  });

  testWidgets('menos de 1024 bytes se muestran en B', (tester) async {
    await pump(tester, _FakePicker(_file('a.csv', 1023)));

    await tapPick(tester);

    expect(find.text('1023 B'), findsOneWidget);
  });

  testWidgets('1 MB justo se acepta', (tester) async {
    await pump(tester, _FakePicker(_file('a.csv', 1048576)));

    await tapPick(tester);

    expect(find.byKey(const Key('csv-file-error')), findsNothing);
    expect(find.text('1024,0 KB'), findsOneWidget);
    expect(changes.single, isNotNull);
  });

  testWidgets('un archivo de más de 1 MB se rechaza y avisa con null', (
    tester,
  ) async {
    await pump(tester, _FakePicker(_file('grande.csv', 1048577)));

    await tapPick(tester);

    expect(
      textOf(tester, const Key('csv-file-error')),
      'El archivo supera el máximo de 1 MB.',
    );
    expect(changes, [null]);
    expect(find.byKey(const Key('csv-file-name')), findsNothing);
  });

  testWidgets('cancelar el selector mantiene la selección', (tester) async {
    final picker = _FakePicker(null);
    await pump(tester, picker, initial: _file('elegido.csv', 100));

    await tapPick(tester);

    expect(changes, isEmpty);
    expect(textOf(tester, const Key('csv-file-name')), 'elegido.csv');
  });

  testWidgets('si el selector falla muestra No se pudo leer el archivo.', (
    tester,
  ) async {
    await pump(tester, _FakePicker(Exception('boom')));

    await tapPick(tester);

    expect(
      textOf(tester, const Key('csv-file-error')),
      'No se pudo leer el archivo.',
    );
    expect(changes, isEmpty);
  });

  group('pantalla angosta', () {
    setUpAll(loadRoboto);

    testWidgets('a 320 px un nombre de 120 caracteres no desborda', (
      tester,
    ) async {
      final name = '${'a' * 116}.csv';
      expect(name.length, 120);
      await pump(
        tester,
        _FakePicker(_file(name, 1536)),
        size: const Size(320, 640),
      );

      await tapPick(tester);

      expect(textOf(tester, const Key('csv-file-name')), name);
      expect(tester.takeException(), isNull);
    });
  });
}
