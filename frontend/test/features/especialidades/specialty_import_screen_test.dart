import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/files/csv_file_picker.dart';
import 'package:agenda_medica/core/files/csv_file_saver.dart';
import 'package:agenda_medica/core/files/csv_parser.dart';
import 'package:agenda_medica/core/files/picked_csv_file.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_import.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_import_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_import_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_import_repository.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/specialty_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';
import '../../helpers/recording_csv_saver.dart';
import '../../helpers/specialty_errors_csv.dart';
import '../../helpers/specialty_import_csv.dart';

class _FakePicker implements CsvFilePicker {
  _FakePicker(this.result);

  PickedCsvFile? result;

  @override
  Future<PickedCsvFile?> pick() async => result;
}

/// Previsualiza con [inner] pero falla al confirmar con [error].
class _ConfirmFailingRepository implements SpecialtyImportRepository {
  _ConfirmFailingRepository(this.inner, this.error);

  final SpecialtyImportRepository inner;
  final Object error;

  @override
  Future<SpecialtyImportPreview> preview(PickedCsvFile file) =>
      inner.preview(file);

  @override
  Future<SpecialtyImportResult> confirm(PickedCsvFile file) async =>
      throw error;
}

/// Un repositorio que siempre falla con [error].
class _FailingRepository implements SpecialtyImportRepository {
  _FailingRepository(this.error);

  final Object error;

  @override
  Future<SpecialtyImportPreview> preview(PickedCsvFile file) async =>
      throw error;

  @override
  Future<SpecialtyImportResult> confirm(PickedCsvFile file) async =>
      throw error;
}

/// Un repositorio que espera a que se complete [gate] antes de responder.
class _GatedRepository implements SpecialtyImportRepository {
  _GatedRepository(this.gate, this.inner);

  final Completer<void> gate;
  final SpecialtyImportRepository inner;

  @override
  Future<SpecialtyImportPreview> preview(PickedCsvFile file) async {
    await gate.future;
    return inner.preview(file);
  }

  @override
  Future<SpecialtyImportResult> confirm(PickedCsvFile file) async {
    await gate.future;
    return inner.confirm(file);
  }
}

/// Cuenta las llamadas a `confirm` y delega en [inner].
class _CountingRepository implements SpecialtyImportRepository {
  _CountingRepository(this.inner);

  final SpecialtyImportRepository inner;
  int confirmCalls = 0;

  @override
  Future<SpecialtyImportPreview> preview(PickedCsvFile file) =>
      inner.preview(file);

  @override
  Future<SpecialtyImportResult> confirm(PickedCsvFile file) {
    confirmCalls++;
    return inner.confirm(file);
  }
}

typedef _Env = ({
  GoRouter router,
  FakeAdminDatabase db,
  _FakePicker picker,
  RecordingCsvSaver saver,
});

Future<_Env> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
  String initialLocation = kImportSpecialtiesPath,
  PickedCsvFile? file,
  RecordingCsvSaver? saver,
  SpecialtyImportRepository Function(FakeAdminDatabase db)? repository,
}) async {
  final db = FakeAdminDatabase();
  final picker = _FakePicker(file ?? specialtyImportFile());
  final recording = saver ?? RecordingCsvSaver();
  final router = await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: kSpecialtiesPath,
        builder: (_, _) => const SpecialtiesScreen(),
      ),
      GoRoute(
        path: kImportSpecialtiesPath,
        builder: (_, _) => const SpecialtyImportScreen(),
      ),
    ],
    overrides: [
      csvFilePickerProvider.overrideWithValue(picker),
      csvFileSaverProvider.overrideWithValue(recording),
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(db, latency: Duration.zero),
      ),
      specialtySearchRepositoryProvider.overrideWith(
        (ref) async =>
            FakeSpecialtySearchRepository(db, latency: Duration.zero),
      ),
      specialtyImportRepositoryProvider.overrideWith(
        (ref) async =>
            repository?.call(db) ??
            FakeSpecialtyImportRepository(db, latency: Duration.zero),
      ),
    ],
  );
  return (router: router, db: db, picker: picker, saver: recording);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester) => _tap(tester, 'csv-pick-button');

Future<void> _preview(WidgetTester tester) async {
  await _pick(tester);
  await _tap(tester, 'import-preview-button');
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed != null;

const _titles = {
  3: 'Fila 3: Traumatología',
  4: 'Fila 4: Cardiología',
  6: 'Fila 6: Pediatría',
  7: 'Fila 7',
};

const _previewErrors = {
  3: 'requiere_pase debe ser si o no',
  4: 'La especialidad ya existe en el sistema',
  6: 'Nombre duplicado. Primera aparición válida en fila 5',
  7: 'El nombre es obligatorio',
};

const _confirmErrors = {
  3: 'requiere_pase debe ser si o no',
  4: 'Ya existe una especialidad registrada con ese nombre.',
  6: 'Nombre duplicado. Primera aparición válida en fila 5',
  7: 'El nombre es obligatorio',
};

/// Un archivo en el que ninguna fila sirve.
final _allInvalid = specialtyCsvFile(
  '$kSpecialtyImportHeader\nCardiología,si\n',
);

void main() {
  testWidgets('sin archivo muestra las instrucciones y no deja previsualizar', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Cargar especialidades desde CSV'), findsOneWidget);
    final instructions = _text(tester, 'import-instructions');
    expect(instructions, contains('nombre'));
    expect(instructions, contains('requiere_pase'));
    expect(instructions, contains('si o no'));
    expect(
      instructions,
      contains('separador coma o punto y coma, UTF-8, hasta 1 MB y 1000 filas'),
    );
    expect(_enabled(tester, 'import-preview-button'), isFalse);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-total')), findsNothing);
  });

  testWidgets('las instrucciones dicen que el orden de las columnas no '
      'importa', (tester) async {
    await _pump(tester);

    final instructions = _text(tester, 'import-instructions');
    expect(
      instructions,
      'Elegí un archivo CSV con una especialidad por fila y estas dos '
      'columnas (el orden no importa): nombre y requiere_pase (si o no). Las '
      'que ya existen no se modifican. Formato: separador coma o punto y '
      'coma, UTF-8, hasta 1 MB y 1000 filas.',
    );
    expect(instructions, isNot(contains('en este orden')));
  });

  testWidgets('con un archivo elegido se puede previsualizar', (tester) async {
    await _pump(tester);

    await _pick(tester);

    expect(find.text('especialidades-prueba.csv'), findsOneWidget);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('previsualizar muestra los totales y las 4 filas con error', (
    tester,
  ) async {
    final env = await _pump(tester);

    await _preview(tester);

    expect(_text(tester, 'import-total'), 'Total: 7');
    expect(_text(tester, 'import-valid'), 'Válidas: 3');
    expect(_text(tester, 'import-invalid'), 'Con error: 4');
    for (final entry in _titles.entries) {
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'fila ${entry.key}',
      );
      expect(
        _text(tester, 'import-error-row-${entry.key}'),
        _previewErrors[entry.key],
      );
    }
    for (final valid in [2, 5, 8]) {
      expect(find.textContaining('Fila $valid'), findsNothing);
      expect(find.byKey(Key('import-error-row-$valid')), findsNothing);
    }
    expect(find.byKey(const Key('import-confirm-button')), findsOneWidget);
    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(env.db.specialties.length, 3);
  });

  testWidgets('confirmar muestra importadas y rechazadas', (tester) async {
    final env = await _pump(tester);
    await _preview(tester);

    await _tap(tester, 'import-confirm-button');

    expect(_text(tester, 'import-imported'), 'Importadas: 3');
    expect(_text(tester, 'import-rejected'), 'Rechazadas: 4');
    for (final entry in _titles.entries) {
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'fila ${entry.key}',
      );
      expect(
        _text(tester, 'import-error-row-${entry.key}'),
        _confirmErrors[entry.key],
      );
    }
    expect(find.byKey(const Key('import-back-button')), findsOneWidget);
    expect(find.byKey(const Key('import-again-button')), findsOneWidget);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-total')), findsNothing);
    expect(env.db.specialties.length, 6);
  });

  testWidgets('"Confirmar importación" no aparece si ninguna fila sirve', (
    tester,
  ) async {
    await _pump(tester, file: _allInvalid);

    await _preview(tester);

    expect(_text(tester, 'import-valid'), 'Válidas: 0');
    expect(_text(tester, 'import-invalid'), 'Con error: 1');
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
  });

  testWidgets('cambiar de archivo borra el resultado', (tester) async {
    final env = await _pump(tester);
    await _preview(tester);
    expect(find.byKey(const Key('import-total')), findsOneWidget);

    env.picker.result = _allInvalid;
    await _pick(tester);

    expect(find.byKey(const Key('import-total')), findsNothing);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-error-row-3')), findsNothing);
    expect(find.byKey(const Key('import-error')), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('cambiar de archivo después de confirmar vuelve al inicio', (
    tester,
  ) async {
    final env = await _pump(tester);
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');
    expect(find.byKey(const Key('import-imported')), findsOneWidget);

    env.picker.result = _allInvalid;
    await _pick(tester);

    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(find.byKey(const Key('import-back-button')), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('"Cargar otro archivo" vuelve a empezar', (tester) async {
    await _pump(tester);
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');

    await _tap(tester, 'import-again-button');

    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(find.byKey(const Key('import-back-button')), findsNothing);
    expect(find.text('especialidades-prueba.csv'), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isFalse);
  });

  testWidgets('"Volver a Especialidades" lleva al listado con las 3 nuevas', (
    tester,
  ) async {
    final env = await _pump(tester);
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');

    await _tap(tester, 'import-back-button');

    expect(currentLocation(env.router), kSpecialtiesPath);
    for (final name in [
      'Cardiología',
      'Dermatología',
      'Medicina General',
      'Neurología',
      'Pediatría',
      'Oftalmología',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('la flecha del AppBar vuelve a Especialidades', (tester) async {
    final env = await _pump(tester);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(currentLocation(env.router), kSpecialtiesPath);
  });

  testWidgets('un CSV_INVALIDO del servidor se muestra en import-error', (
    tester,
  ) async {
    await _pump(
      tester,
      repository: (_) => _FailingRepository(
        const ApiException(
          'El archivo supera el tamaño máximo permitido (1 MB)',
        ),
      ),
    );

    await _preview(tester);

    expect(
      _text(tester, 'import-error'),
      'El archivo supera el tamaño máximo permitido (1 MB)',
    );
    expect(find.byKey(const Key('import-total')), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('un encabezado equivocado se muestra en import-error', (
    tester,
  ) async {
    await _pump(tester, file: specialtyCsvFile('nombre,otra\nA,si\n'));

    await _preview(tester);

    expect(
      _text(tester, 'import-error'),
      'El CSV debe tener exactamente las columnas: nombre, requiere_pase',
    );
  });

  testWidgets('mientras previsualiza no se puede volver a tocar el botón', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pump(
      tester,
      repository: (db) => _GatedRepository(
        gate,
        FakeSpecialtyImportRepository(db, latency: Duration.zero),
      ),
    );
    await _pick(tester);

    await tester.tap(find.byKey(const Key('import-preview-button')));
    await tester.pump();

    expect(_enabled(tester, 'import-preview-button'), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-total')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('un error al confirmar se muestra y deja volver a intentar', (
    tester,
  ) async {
    final env = await _pump(
      tester,
      repository: (db) => _ConfirmFailingRepository(
        FakeSpecialtyImportRepository(db, latency: Duration.zero),
        const ApiException('No pudimos conectarnos. Probá de nuevo.'),
      ),
    );
    await _preview(tester);

    await _tap(tester, 'import-confirm-button');

    expect(
      _text(tester, 'import-error'),
      'No pudimos conectarnos. Probá de nuevo.',
    );
    expect(_text(tester, 'import-total'), 'Total: 7');
    expect(find.byKey(const Key('import-confirm-button')), findsOneWidget);
    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(env.db.specialties.length, 3);
  });

  testWidgets(
    'el botón "Cargar desde CSV" de Especialidades lleva a importar',
    (tester) async {
      final env = await _pump(tester, initialLocation: kSpecialtiesPath);
      expect(find.text('Cargar desde CSV'), findsOneWidget);
      expect(find.text('Nueva especialidad'), findsOneWidget);

      await tester.tap(find.byKey(const Key('specialties-import-button')));
      await tester.pumpAndSettle();

      expect(currentLocation(env.router), kImportSpecialtiesPath);
      expect(find.text('Cargar especialidades desde CSV'), findsOneWidget);
    },
  );

  // Van al final: Roboto se carga una sola vez por archivo y los tests que
  // vinieran después dejarían de usar la fuente de prueba. Con Roboto el texto
  // mide como en un celular.
  group('descarga de las filas con error', () {
    setUpAll(loadRoboto);
    const columns = ['nombre', 'requiere_pase', 'error'];

    testWidgets('la previsualización ofrece bajar las filas con error', (
      tester,
    ) async {
      final env = await _pump(tester);
      await _preview(tester);

      expect(find.text('Descargar filas con error'), findsOneWidget);
      await _tap(tester, 'import-download-button');

      expect(env.saver.saved.length, 1);
      expect(env.saver.saved.single.name, 'especialidades-prueba-errores.csv');
      expect(
        env.saver.saved.single.bytes,
        Uint8List.fromList(utf8.encode(kSpecialtyErrorsCsvText)),
      );
    });

    testWidgets('el resultado ofrece bajar las filas rechazadas', (
      tester,
    ) async {
      final env = await _pump(tester);
      await _preview(tester);
      await _tap(tester, 'import-confirm-button');

      expect(find.text('Descargar filas rechazadas'), findsOneWidget);
      await _tap(tester, 'import-download-button');

      expect(env.saver.saved.single.name, 'especialidades-prueba-errores.csv');
      final table = parseCsv(
        env.saver.saved.single.bytes,
        expectedHeader: columns,
      );
      expect(table.rows.map((r) => r.sublist(0, 2)), [
        ['Traumatología', 'tal vez'],
        ['Cardiología', 'si'],
        ['Pediatría', 'no'],
        ['', 'si'],
      ]);
      expect(table.rows.map((r) => r[2]), [
        'requiere_pase debe ser si o no',
        'Ya existe una especialidad registrada con ese nombre.',
        'Nombre duplicado. Primera aparición válida en fila 5',
        'El nombre es obligatorio',
      ]);
    });

    testWidgets('con un archivo sin errores no hay botón', (tester) async {
      await _pump(
        tester,
        file: specialtyCsvFile('nombre,requiere_pase\nNeurología,si\n'),
      );
      await _preview(tester);

      expect(find.byKey(const Key('import-confirm-button')), findsOneWidget);
      expect(find.byKey(const Key('import-download-button')), findsNothing);

      await _tap(tester, 'import-confirm-button');

      expect(find.byKey(const Key('import-imported')), findsOneWidget);
      expect(find.byKey(const Key('import-download-button')), findsNothing);
    });

    testWidgets('a 320 px con Roboto no desborda, ni con el aviso', (
      tester,
    ) async {
      final saver = RecordingCsvSaver()..error = StateError('falló');
      await _pump(tester, size: const Size(320, 640), saver: saver);
      await _preview(tester);
      expect(tester.takeException(), isNull);

      await _tap(tester, 'import-download-button');

      expect(find.byKey(const Key('import-download-error')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tap(tester, 'import-confirm-button');
      expect(find.text('Descargar filas rechazadas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('la previsualización con las 4 filas de error no desborda', (
      tester,
    ) async {
      await _pump(tester, size: const Size(320, 640));

      await _preview(tester);

      expect(tester.takeException(), isNull);
      for (final entry in _titles.entries) {
        final finder = find.text(entry.value);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(finder, findsOneWidget, reason: 'fila ${entry.key}');
      }
      await tester.ensureVisible(
        find.byKey(const Key('import-confirm-button')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('el resultado final no desborda', (tester) async {
      await _pump(tester, size: const Size(320, 640));
      await _preview(tester);

      await _tap(tester, 'import-confirm-button');

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('import-error-row-4')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('import-again-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-back-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('los dos botones de Especialidades entran en 320 px', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        initialLocation: kSpecialtiesPath,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('specialties-import-button')),
        findsOneWidget,
      );
      expect(find.text('Nueva especialidad'), findsOneWidget);
    });
  });

  testWidgets('tocar Confirmar importación dos veces en el mismo cuadro '
      'confirma una sola vez', (tester) async {
    late _CountingRepository counting;
    final env = await _pump(
      tester,
      repository: (db) => counting = _CountingRepository(
        FakeSpecialtyImportRepository(db, latency: Duration.zero),
      ),
    );
    await _preview(tester);
    final confirm = find.byKey(const Key('import-confirm-button'));
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();

    // tester.tap no redibuja entre medio: los dos toques llegan con el
    // botón todavía encendido.
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(counting.confirmCalls, 1);
    expect(_text(tester, 'import-imported'), 'Importadas: 3');
    expect(_text(tester, 'import-rejected'), 'Rechazadas: 4');
    expect(env.db.specialties.length, 6);
  });
}
