import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/files/csv_file_picker.dart';
import 'package:agenda_medica/core/files/picked_csv_file.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_import.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_import_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_import_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_import_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/screens/clinic_import_screen.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/clinic_import_csv.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

class _FakePicker implements CsvFilePicker {
  _FakePicker(this.result);

  PickedCsvFile? result;

  @override
  Future<PickedCsvFile?> pick() async => result;
}

/// Previsualiza con [inner] pero falla al confirmar con [error].
class _ConfirmFailingRepository implements ClinicImportRepository {
  _ConfirmFailingRepository(this.inner, this.error);

  final ClinicImportRepository inner;
  final Object error;

  @override
  Future<ClinicImportPreview> preview(PickedCsvFile file) =>
      inner.preview(file);

  @override
  Future<ClinicImportResult> confirm(PickedCsvFile file) async => throw error;
}

/// Un repositorio que siempre falla con [error].
class _FailingRepository implements ClinicImportRepository {
  _FailingRepository(this.error);

  final Object error;

  @override
  Future<ClinicImportPreview> preview(PickedCsvFile file) async => throw error;

  @override
  Future<ClinicImportResult> confirm(PickedCsvFile file) async => throw error;
}

/// Un repositorio que espera a que se complete [gate] antes de responder.
class _GatedRepository implements ClinicImportRepository {
  _GatedRepository(this.gate, this.inner);

  final Completer<void> gate;
  final ClinicImportRepository inner;

  @override
  Future<ClinicImportPreview> preview(PickedCsvFile file) async {
    await gate.future;
    return inner.preview(file);
  }

  @override
  Future<ClinicImportResult> confirm(PickedCsvFile file) async {
    await gate.future;
    return inner.confirm(file);
  }
}

/// Cuenta las llamadas a `confirm` y delega en [inner].
class _CountingRepository implements ClinicImportRepository {
  _CountingRepository(this.inner);

  final ClinicImportRepository inner;
  int confirmCalls = 0;

  @override
  Future<ClinicImportPreview> preview(PickedCsvFile file) =>
      inner.preview(file);

  @override
  Future<ClinicImportResult> confirm(PickedCsvFile file) {
    confirmCalls++;
    return inner.confirm(file);
  }
}

typedef _Env = ({GoRouter router, FakeAdminDatabase db, _FakePicker picker});

Future<_Env> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1800),
  String initialLocation = kImportClinicsPath,
  PickedCsvFile? file,
  ClinicImportRepository Function(FakeAdminDatabase db)? repository,
}) async {
  final db = FakeAdminDatabase();
  final picker = _FakePicker(file ?? clinicImportFile());
  final router = await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: initialLocation,
    // Anidada como en la app: el listado queda debajo de la carga y conserva
    // sus filtros y su sentido.
    routes: [
      GoRoute(
        path: kClinicsPath,
        builder: (_, _) => const ClinicsScreen(),
        routes: [
          GoRoute(
            path: 'importar',
            builder: (_, _) => const ClinicImportScreen(),
          ),
        ],
      ),
    ],
    overrides: [
      csvFilePickerProvider.overrideWithValue(picker),
      clinicRepositoryProvider.overrideWith(
        (ref) async => FakeClinicRepository(db, latency: Duration.zero),
      ),
      clinicSearchRepositoryProvider.overrideWith(
        (ref) async => FakeClinicSearchRepository(db, latency: Duration.zero),
      ),
      clinicImportRepositoryProvider.overrideWith(
        (ref) async =>
            repository?.call(db) ??
            FakeClinicImportRepository(db, latency: Duration.zero),
      ),
    ],
  );
  return (router: router, db: db, picker: picker);
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

/// Los nombres del listado de consultorios, de arriba hacia abajo.
List<String> _listed(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
    (tile.title! as Text).data!,
];

const _titles = {
  3: 'Fila 3: Consultorio 7',
  4: 'Fila 4: Consultorio 21',
  5: 'Fila 5: Consultorio 20',
  6: 'Fila 6',
  8: 'Fila 8: consultorio 12',
};

const _errors = {
  3: 'El consultorio ya existe en el sistema',
  4: 'La ubicación es obligatoria',
  5: 'Nombre duplicado. Primera aparición válida en fila 2',
  6: 'El nombre es obligatorio',
  8: 'El consultorio ya existe en el sistema',
};

/// Un archivo en el que ninguna fila sirve.
final _allInvalid = clinicCsvFile(
  '$kClinicImportHeader\nConsultorio 7,Piso 1\n',
);

void main() {
  testWidgets('sin archivo muestra las instrucciones y no deja previsualizar', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Cargar consultorios desde CSV'), findsOneWidget);
    final instructions = _text(tester, 'import-instructions');
    expect(instructions, contains('nombre'));
    expect(instructions, contains('ubicacion'));
    expect(
      instructions,
      contains('separador coma o punto y coma, UTF-8, hasta 1 MB y 1000 filas'),
    );
    expect(_enabled(tester, 'import-preview-button'), isFalse);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-total')), findsNothing);
  });

  testWidgets('con un archivo elegido se puede previsualizar', (tester) async {
    await _pump(tester);

    await _pick(tester);

    expect(find.text('consultorios-prueba.csv'), findsOneWidget);
    expect(_enabled(tester, 'import-preview-button'), isTrue);
  });

  testWidgets('previsualizar muestra los totales y las 5 filas con error', (
    tester,
  ) async {
    final env = await _pump(tester);

    await _preview(tester);

    expect(_text(tester, 'import-total'), 'Total: 7');
    expect(_text(tester, 'import-valid'), 'Válidas: 2');
    expect(_text(tester, 'import-invalid'), 'Con error: 5');
    for (final entry in _titles.entries) {
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'fila ${entry.key}',
      );
      expect(
        _text(tester, 'import-error-row-${entry.key}'),
        _errors[entry.key],
      );
    }
    for (final valid in [2, 7]) {
      expect(find.textContaining('Fila $valid'), findsNothing);
      expect(find.byKey(Key('import-error-row-$valid')), findsNothing);
    }
    expect(find.byKey(const Key('import-confirm-button')), findsOneWidget);
    expect(find.byKey(const Key('import-imported')), findsNothing);
    expect(env.db.clinics.length, 3);
  });

  testWidgets('confirmar muestra importados y rechazados', (tester) async {
    final env = await _pump(tester);
    await _preview(tester);

    await _tap(tester, 'import-confirm-button');

    expect(_text(tester, 'import-imported'), 'Importadas: 2');
    expect(_text(tester, 'import-rejected'), 'Rechazadas: 5');
    for (final entry in _titles.entries) {
      expect(
        find.text(entry.value),
        findsOneWidget,
        reason: 'fila ${entry.key}',
      );
      expect(
        _text(tester, 'import-error-row-${entry.key}'),
        _errors[entry.key],
      );
    }
    expect(find.byKey(const Key('import-back-button')), findsOneWidget);
    expect(find.byKey(const Key('import-again-button')), findsOneWidget);
    expect(find.byKey(const Key('import-confirm-button')), findsNothing);
    expect(find.byKey(const Key('import-total')), findsNothing);
    expect(env.db.clinics.length, 5);
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
    expect(find.text('consultorios-prueba.csv'), findsNothing);
    expect(_enabled(tester, 'import-preview-button'), isFalse);
  });

  testWidgets('"Volver a Consultorios" muestra los 5 en orden natural', (
    tester,
  ) async {
    final env = await _pump(tester, initialLocation: kClinicsPath);
    expect(_listed(tester), [
      'Consultorio 3',
      'Consultorio 7',
      'Consultorio 12',
    ]);
    await tester.tap(find.byKey(const Key('clinics-import-button')));
    await tester.pumpAndSettle();
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');

    await _tap(tester, 'import-back-button');

    expect(currentLocation(env.router), kClinicsPath);
    expect(_listed(tester), [
      'Consultorio 3',
      'Consultorio 7',
      'Consultorio 12',
      'Consultorio 20',
      'Consultorio 22',
    ]);
  });

  testWidgets('un filtro y el sentido Descendente siguen puestos al volver', (
    tester,
  ) async {
    final env = await _pump(tester, initialLocation: kClinicsPath);
    await tester.enterText(find.byKey(const Key('clinic-filter-name')), '2');
    await _tap(tester, 'clinic-filter-search');
    await _tap(tester, 'clinic-filter-direction');
    expect(_listed(tester), ['Consultorio 12']);
    expect(find.text('Descendente'), findsOneWidget);
    await _tap(tester, 'clinics-import-button');
    await _preview(tester);
    await _tap(tester, 'import-confirm-button');

    await _tap(tester, 'import-back-button');

    expect(currentLocation(env.router), kClinicsPath);
    expect(_listed(tester), [
      'Consultorio 22',
      'Consultorio 20',
      'Consultorio 12',
    ]);
    expect(find.text('Descendente'), findsOneWidget);
  });

  testWidgets('la flecha del AppBar vuelve a Consultorios', (tester) async {
    final env = await _pump(tester);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(currentLocation(env.router), kClinicsPath);
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
    await _pump(tester, file: clinicCsvFile('nombre,otra\nA,B\n'));

    await _preview(tester);

    expect(
      _text(tester, 'import-error'),
      'El CSV debe tener exactamente las columnas: nombre, ubicacion',
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
        FakeClinicImportRepository(db, latency: Duration.zero),
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
        FakeClinicImportRepository(db, latency: Duration.zero),
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
    expect(env.db.clinics.length, 3);
  });

  testWidgets('el botón "Cargar desde CSV" de Consultorios lleva a importar', (
    tester,
  ) async {
    final env = await _pump(tester, initialLocation: kClinicsPath);
    expect(find.text('Cargar desde CSV'), findsOneWidget);
    expect(find.text('Nuevo consultorio'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clinics-import-button')));
    await tester.pumpAndSettle();

    expect(currentLocation(env.router), kImportClinicsPath);
    expect(find.text('Cargar consultorios desde CSV'), findsOneWidget);
  });

  // Van al final: Roboto se carga una sola vez por archivo y los tests que
  // vinieran después dejarían de usar la fuente de prueba. Con Roboto el texto
  // mide como en un celular.
  group('a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('la previsualización con las 5 filas de error no desborda', (
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
      await tester.ensureVisible(find.byKey(const Key('import-error-row-5')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('import-again-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-back-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('los dos botones de Consultorios entran en 320 px', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(320, 640),
        initialLocation: kClinicsPath,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('clinics-import-button')), findsOneWidget);
      expect(find.text('Nuevo consultorio'), findsOneWidget);
    });
  });

  testWidgets('tocar Confirmar importación dos veces en el mismo cuadro '
      'confirma una sola vez', (tester) async {
    late _CountingRepository counting;
    final env = await _pump(
      tester,
      repository: (db) => counting = _CountingRepository(
        FakeClinicImportRepository(db, latency: Duration.zero),
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
    expect(_text(tester, 'import-imported'), 'Importadas: 2');
    expect(_text(tester, 'import-rejected'), 'Rechazadas: 5');
    expect(env.db.clinics.length, 5);
  });
}
