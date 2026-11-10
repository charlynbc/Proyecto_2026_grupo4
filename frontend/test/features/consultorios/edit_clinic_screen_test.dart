import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_correction_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_correction_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_correction_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:agenda_medica/features/consultorios/screens/edit_clinic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

class _RecordingCorrectionRepository implements ClinicCorrectionRepository {
  _RecordingCorrectionRepository(this.delegate);

  final FakeClinicCorrectionRepository delegate;
  final calls = <(int, String?, String?)>[];
  ClinicCorrectionException? error;
  Completer<Clinic>? completer;

  @override
  Future<Clinic> correct(int id, {String? name, String? location}) {
    calls.add((id, name, location));
    final pending = completer;
    if (pending != null) return pending.future;
    final failure = error;
    if (failure != null) return Future.error(failure);
    return delegate.correct(id, name: name, location: location);
  }
}

class _RecordingSearchRepository extends FakeClinicSearchRepository {
  _RecordingSearchRepository(this.db) : super(db, latency: Duration.zero);

  final FakeAdminDatabase db;
  static int calls = 0;
  static final locations = <String>[];

  @override
  Future<List<Clinic>> search(ClinicFilters filters) {
    calls++;
    locations.add(db.clinics.first.location);
    return super.search(filters);
  }
}

Future<(GoRouter, FakeAdminDatabase)> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1200),
  String initialLocation = kClinicsPath,
  _RecordingCorrectionRepository? correction,
  FakeAdminDatabase? database,
}) async {
  final db = database ?? FakeAdminDatabase();
  _RecordingSearchRepository.calls = 0;
  _RecordingSearchRepository.locations.clear();
  final search = _RecordingSearchRepository(db);
  correction ??= _RecordingCorrectionRepository(
    FakeClinicCorrectionRepository(db, latency: Duration.zero),
  );
  final router = await pumpAdminScreens(
    tester,
    size: size,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: kClinicsPath,
        builder: (_, _) => const ClinicsScreen(),
        routes: [
          GoRoute(
            path: ':id/corregir',
            builder: (_, state) => EditClinicScreen(
              id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
    ],
    overrides: [
      clinicRepositoryProvider.overrideWith(
        (ref) async => FakeClinicRepository(db, latency: Duration.zero),
      ),
      clinicSearchRepositoryProvider.overrideWith((ref) async => search),
      clinicCorrectionRepositoryProvider.overrideWith(
        (ref) async => correction!,
      ),
    ],
  );
  return (router, db);
}

Finder _editFields() => find.descendant(
  of: find.byType(Form),
  matching: find.byType(TextFormField),
);

Future<void> _openEdit(WidgetTester tester, int id) async {
  await tester.tap(find.byKey(Key('clinic-edit-$id')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);

  test('clinicEditPath arma la ruta de corrección', () {
    expect(clinicEditPath(7), '/admin/consultorios/7/corregir');
  });

  testWidgets('el formulario carga los datos y guardar empieza deshabilitado', (
    tester,
  ) async {
    await _pump(tester, initialLocation: '/admin/consultorios/1/corregir');

    expect(find.text('Corregir consultorio'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(_editFields().at(0)).controller!.text,
      'Consultorio 3',
    );
    expect(
      tester.widget<TextFormField>(_editFields().at(1)).controller!.text,
      'Planta baja',
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('edit-clinic-save')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('guardar solo ubicación envía solo ese campo y vuelve', (
    tester,
  ) async {
    final db = FakeAdminDatabase();
    final correction = _RecordingCorrectionRepository(
      FakeClinicCorrectionRepository(db, latency: Duration.zero),
    );
    await _pump(tester, correction: correction, database: db);
    await _openEdit(tester, 1);
    await tester.enterText(_editFields().at(1), 'Planta alta');
    await tester.pump();
    final searchesBeforeSave = _RecordingSearchRepository.calls;
    _RecordingSearchRepository.locations.clear();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('edit-clinic-save')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('edit-clinic-save')));
    await tester.pumpAndSettle();

    expect(correction.calls, [(1, null, 'Planta alta')]);
    expect(db.clinics.first.location, 'Planta alta');
    expect(_RecordingSearchRepository.calls, greaterThan(searchesBeforeSave));
    expect(_RecordingSearchRepository.locations, contains('Planta alta'));
    expect(find.text('Consultorios'), findsOneWidget);
    expect(find.text('Consultorio corregido.'), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('Planta baja'), findsNothing);
    expect(find.text('Planta alta'), findsOneWidget);
  });

  testWidgets('duplicado aparece bajo el nombre y permanece en edición', (
    tester,
  ) async {
    final db = FakeAdminDatabase();
    final correction =
        _RecordingCorrectionRepository(
            FakeClinicCorrectionRepository(db, latency: Duration.zero),
          )
          ..error = const ClinicCorrectionException(
            ClinicCorrectionFailure.duplicate,
            'Ya existe un consultorio con ese nombre o número.',
          );
    await _pump(tester, correction: correction, database: db);
    await _openEdit(tester, 2);
    await tester.enterText(_editFields().at(0), 'Consultorio 12');
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-clinic-save')));
    await tester.pumpAndSettle();

    expect(correction.calls, [(2, 'Consultorio 12', null)]);
    expect(find.byKey(const Key('edit-clinic-error')), findsOneWidget);
    expect(
      find.text('Ya existe un consultorio con ese nombre o número.'),
      findsOneWidget,
    );
    expect(find.text('Corregir consultorio'), findsOneWidget);
  });

  for (final (failure, message) in [
    (ClinicCorrectionFailure.notFound, 'El consultorio ya no está disponible.'),
    (ClinicCorrectionFailure.validation, 'Revisá los datos enviados.'),
    (ClinicCorrectionFailure.other, 'Error informado por el servidor.'),
  ]) {
    testWidgets('$failure aparece arriba del formulario', (tester) async {
      final db = FakeAdminDatabase();
      final correction = _RecordingCorrectionRepository(
        FakeClinicCorrectionRepository(db, latency: Duration.zero),
      )..error = ClinicCorrectionException(failure, message);
      await _pump(tester, correction: correction, database: db);
      await _openEdit(tester, 1);
      await tester.enterText(_editFields().at(1), 'Planta alta');
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-clinic-save')));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Corregir consultorio'), findsOneWidget);
    });
  }

  testWidgets('renombrar mantiene filtro y sentido y aplica orden natural', (
    tester,
  ) async {
    final (router, db) = await _pump(tester);
    await tester.enterText(
      find.byKey(const Key('clinic-filter-name')),
      'Consultorio',
    );
    await tester.tap(find.byKey(const Key('clinic-filter-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clinic-filter-direction')));
    await tester.pumpAndSettle();
    expect(find.text('Descendente'), findsOneWidget);

    await _openEdit(tester, 1);
    await tester.enterText(_editFields().at(0), 'Consultorio 30');
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-clinic-save')));
    await tester.pumpAndSettle();

    expect(find.text('Descendente'), findsOneWidget);
    expect(find.byKey(const Key('clinic-filter-name')), findsOneWidget);
    expect(db.clinics.first.name, 'Consultorio 30');
    expect(
      tester.getTopLeft(find.text('Consultorio 30')).dy,
      lessThan(tester.getTopLeft(find.text('Consultorio 12')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Consultorio 12')).dy,
      lessThan(tester.getTopLeft(find.text('Consultorio 7')).dy),
    );
    expect(currentLocation(router), kClinicsPath);
  });

  testWidgets('id inexistente muestra el estado de no encontrado', (
    tester,
  ) async {
    await _pump(tester, initialLocation: '/admin/consultorios/9999/corregir');

    expect(find.text('No encontramos ese consultorio.'), findsOneWidget);
    expect(find.byKey(const Key('edit-clinic-back')), findsOneWidget);
  });

  testWidgets('doble toque seguido hace una sola llamada', (tester) async {
    final db = FakeAdminDatabase();
    final correction = _RecordingCorrectionRepository(
      FakeClinicCorrectionRepository(db, latency: Duration.zero),
    )..completer = Completer<Clinic>();
    await _pump(
      tester,
      correction: correction,
      initialLocation: '/admin/consultorios/1/corregir',
      database: db,
    );
    await tester.enterText(_editFields().at(1), 'Planta alta');
    await tester.pump();

    await tester.tap(find.byKey(const Key('edit-clinic-save')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-clinic-save')));
    await tester.pump();
    expect(correction.calls, [(1, null, 'Planta alta')]);

    correction.completer!.complete(
      const Clinic(id: 1, name: 'Consultorio 3', location: 'Planta alta'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a 320 px lista y formulario con error no desbordan', (
    tester,
  ) async {
    final db = FakeAdminDatabase();
    final correction =
        _RecordingCorrectionRepository(
            FakeClinicCorrectionRepository(db, latency: Duration.zero),
          )
          ..error = const ClinicCorrectionException(
            ClinicCorrectionFailure.duplicate,
            'Ya existe un consultorio con ese nombre o número.',
          );
    await _pump(
      tester,
      size: const Size(320, 900),
      correction: correction,
      database: db,
    );

    expect(find.byKey(const Key('clinic-edit-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _openEdit(tester, 1);
    await tester.enterText(_editFields().at(0), 'Consultorio 7');
    await tester.pump();
    await tester.tap(find.byKey(const Key('edit-clinic-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-clinic-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
