import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/files/csv_file_saver.dart';
import 'package:agenda_medica/core/files/import_errors_download_button.dart';
import 'package:agenda_medica/core/files/picked_csv_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/recording_csv_saver.dart';
import '../../helpers/specialty_errors_csv.dart';

const _header = ['nombre', 'requiere_pase'];
const _button = Key('import-download-button');
const _error = Key('import-download-error');

PickedCsvFile _file({String name = 'especialidades-prueba.csv'}) =>
    PickedCsvFile(
      name: name,
      bytes: Uint8List.fromList(
        utf8.encode(
          'nombre,requiere_pase\n'
          'Neurología,si\n'
          'Traumatología,tal vez\n'
          'Cardiología,si\n'
          'Pediatría,no\n'
          'Pediatría,no\n'
          ',si\n'
          'Oftalmología,no\n',
        ),
      ),
    );

Future<RecordingCsvSaver> _pump(
  WidgetTester tester, {
  PickedCsvFile? file,
  Map<int, String> errors = kSpecialtyErrorsByRow,
  RecordingCsvSaver? saver,
  Size size = const Size(900, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final recording = saver ?? RecordingCsvSaver();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [csvFileSaverProvider.overrideWithValue(recording)],
      child: MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ImportErrorsDownloadButton(
              file: file ?? _file(),
              expectedHeader: _header,
              errorsByRow: errors,
              label: 'Descargar filas rechazadas',
            ),
          ),
        ),
      ),
    ),
  );
  return recording;
}

VoidCallback? _onPressed(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(find.byKey(_button)).onPressed;

void main() {
  setUpAll(loadRoboto);

  testWidgets('sin errores no hay botón', (tester) async {
    await _pump(tester, errors: const {});

    expect(find.byKey(_button), findsNothing);
    expect(find.byKey(_error), findsNothing);
  });

  group('aviso para volver a subir el archivo', () {
    const hintText =
        'Para volver a subir el archivo, borrá la columna error y las '
        'columnas extra_1, extra_2, etc. si las hay.';

    testWidgets('va junto al botón, con una fila o con varias', (tester) async {
      await _pump(tester, errors: const {3: 'requiere_pase debe ser si o no'});
      expect(find.byKey(_button), findsOneWidget);
      expect(find.text(hintText), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(hintText)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(_button)).dy),
      );

      await _pump(tester);
      expect(find.byKey(_button), findsOneWidget);
      expect(find.text(hintText), findsOneWidget);
    });

    testWidgets('sin errores no hay texto', (tester) async {
      await _pump(tester, errors: const {});

      expect(find.text(hintText), findsNothing);
    });

    testWidgets('sigue visible si falla el guardado', (tester) async {
      await _pump(tester, saver: RecordingCsvSaver()..error = StateError('x'));
      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();

      expect(find.byKey(_error), findsOneWidget);
      expect(find.text(hintText), findsOneWidget);
    });
  });

  testWidgets('con errores muestra el botón con su texto', (tester) async {
    await _pump(tester);

    expect(find.byKey(_button), findsOneWidget);
    expect(find.text('Descargar filas rechazadas'), findsOneWidget);
  });

  testWidgets('al tocar guarda el archivo con su nombre y sus bytes', (
    tester,
  ) async {
    final saver = await _pump(tester);

    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    expect(saver.saved.length, 1);
    expect(saver.saved.single.name, 'especialidades-prueba-errores.csv');
    expect(
      saver.saved.single.bytes,
      Uint8List.fromList(utf8.encode(kSpecialtyErrorsCsvText)),
    );
    expect(find.byKey(_error), findsNothing);
  });

  for (final (original, expected) in [
    ('especialidades', 'especialidades-errores.csv'),
    ('lista.de.altas.csv', 'lista.de.altas-errores.csv'),
    ('MAYUS.CSV', 'MAYUS-errores.csv'),
  ]) {
    testWidgets('"$original" se guarda como "$expected"', (tester) async {
      final saver = await _pump(tester, file: _file(name: original));

      await tester.tap(find.byKey(_button));
      await tester.pumpAndSettle();

      expect(saver.saved.single.name, expected);
    });
  }

  testWidgets('un guardador que lanza muestra el aviso', (tester) async {
    final saver = RecordingCsvSaver()..error = StateError('sin permiso');
    await _pump(tester, saver: saver);

    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar el archivo.'), findsOneWidget);
    expect(_onPressed(tester), isNotNull);
  });

  testWidgets('un archivo que ya no se puede leer muestra el aviso', (
    tester,
  ) async {
    final saver = await _pump(
      tester,
      file: PickedCsvFile(name: 'x.csv', bytes: Uint8List.fromList([0xFF])),
    );

    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    expect(find.byKey(_error), findsOneWidget);
    expect(saver.saved, isEmpty);
  });

  testWidgets('el aviso se va al reintentar con éxito', (tester) async {
    final saver = RecordingCsvSaver()..error = StateError('falló');
    await _pump(tester, saver: saver);
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();
    expect(find.byKey(_error), findsOneWidget);

    saver.error = null;
    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    expect(find.byKey(_error), findsNothing);
    expect(saver.saved.length, 2);
  });

  testWidgets('si el guardador vuelve sin hacer nada no hay mensaje', (
    tester,
  ) async {
    final saver = await _pump(tester);

    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    expect(saver.saved.length, 1);
    expect(find.byKey(_error), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(_onPressed(tester), isNotNull);
  });

  testWidgets('mientras guarda queda deshabilitado y vuelve después', (
    tester,
  ) async {
    final saver = RecordingCsvSaver()..gate = Completer<void>();
    await _pump(tester, saver: saver);

    await tester.tap(find.byKey(_button));
    await tester.pump();

    expect(_onPressed(tester), isNull);
    await tester.tap(find.byKey(_button), warnIfMissed: false);
    await tester.pump();
    expect(saver.saved.length, 1);

    saver.gate!.complete();
    await tester.pumpAndSettle();

    expect(_onPressed(tester), isNotNull);
    expect(saver.saved.length, 1);
  });

  testWidgets('un doble toque seguido hace una sola llamada', (tester) async {
    final saver = RecordingCsvSaver()..gate = Completer<void>();
    await _pump(tester, saver: saver);

    // tester.tap no redibuja entre medio: los dos toques llegan con el
    // botón todavía encendido.
    await tester.tap(find.byKey(_button));
    await tester.tap(find.byKey(_button));
    saver.gate!.complete();
    await tester.pumpAndSettle();

    expect(saver.saved.length, 1);
  });

  testWidgets('a 320 px con Roboto no desborda, ni con el aviso', (
    tester,
  ) async {
    final saver = RecordingCsvSaver()..error = StateError('falló');
    await _pump(tester, saver: saver, size: const Size(320, 640));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(_button));
    await tester.pumpAndSettle();

    expect(find.byKey(_error), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
