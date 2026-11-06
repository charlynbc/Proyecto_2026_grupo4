import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:agenda_medica/features/consultorios/screens/new_clinic_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

class _Search extends FakeClinicSearchRepository {
  _Search(super.db) : super(latency: Duration.zero);

  int calls = 0;
  final List<ClinicFilters> queries = [];

  @override
  Future<List<Clinic>> search(ClinicFilters filters) {
    calls++;
    queries.add(filters);
    return super.search(filters);
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

const _numberedClinics = [
  Clinic(id: 3, name: 'Consultorio 3', location: 'Planta baja'),
  Clinic(id: 7, name: 'Consultorio 7', location: 'Piso 1'),
  Clinic(id: 12, name: 'Consultorio 12', location: 'Piso 2'),
];

const _locationClinics = [
  Clinic(id: 9, name: 'Consultorio 9', location: 'Piso 2'),
  Clinic(id: 8, name: 'Consultorio 8', location: 'Piso 10'),
  Clinic(id: 4, name: 'Consultorio 4', location: 'Planta baja'),
];

/// El orden por nombre (4, 8, 9) no coincide con el de la ubicación.
const _accentLocations = [
  Clinic(id: 9, name: 'Consultorio 9', location: 'Zona'),
  Clinic(id: 8, name: 'Consultorio 8', location: 'Ático'),
  Clinic(id: 4, name: 'Consultorio 4', location: 'Piso 1'),
];

Future<_Search> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1400),
  TextScaler textScaler = TextScaler.noScaling,
  List<Clinic>? clinics,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = FakeAdminDatabase();
  db.clinics
    ..clear()
    ..addAll(
      clinics ??
          const [
            Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2, ala norte'),
            Clinic(id: 6, name: 'Consultorio 6', location: 'Piso 2, ala sur'),
            Clinic(id: 12, name: 'Consultorio 12', location: 'Planta baja'),
          ],
    );
  final search = _Search(db);
  final container = ProviderContainer(
    overrides: [
      clinicSearchRepositoryProvider.overrideWith((ref) async => search),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const ClinicsScreen(),
      ),
    ),
  );
  await _settle(tester);
  return search;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final control = find.byKey(ValueKey(key));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await _settle(tester);
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await _tap(tester, key);
  final menuItem = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.role == SemanticsRole.menuItem,
    ),
  );
  expect(menuItem, findsOneWidget);
  final option = find
      .descendant(of: menuItem, matching: find.byType(InkWell))
      .hitTestable();
  expect(option, findsOneWidget);
  await tester.tap(option);
  await tester.pump();
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void _expectNames(WidgetTester tester, List<String> names) {
  expect(find.byType(ListTile), findsNWidgets(names.length));
  for (var i = 0; i < names.length; i++) {
    expect(find.text(names[i]), findsOneWidget);
    if (i == 0) continue;
    expect(
      tester.getTopLeft(find.text(names[i - 1])).dy,
      lessThan(tester.getTopLeft(find.text(names[i])).dy),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);

  testWidgets('al abrir ordena por nombre: 5, 6 y 12', (tester) async {
    final search = await _pump(tester);

    expect(search.calls, 1);
    expect(search.queries.single.toQueryParameters(), isEmpty);
    _expectNames(tester, ['Consultorio 5', 'Consultorio 6', 'Consultorio 12']);
  });

  testWidgets('cambiar a Ubicación busca sola y reordena', (tester) async {
    final search = await _pump(tester);

    await _select(tester, 'clinic-filter-order', 'Ubicación');

    expect(search.calls, 2);
    expect(search.queries.last.toQueryParameters(), {'orden': 'ubicacion'});
    expect(
      search.queries.last.toQueryParameters().containsKey('sentido'),
      isFalse,
    );
    _expectNames(tester, ['Consultorio 5', 'Consultorio 6', 'Consultorio 12']);
  });

  testWidgets('escribir 12 y cambiar el orden no aplica el texto', (
    tester,
  ) async {
    final search = await _pump(tester);
    await _enter(tester, 'clinic-filter-name', '12');

    await _select(tester, 'clinic-filter-order', 'Ubicación');

    expect(search.calls, 2);
    expect(search.queries.last.name, isNull);
    _expectNames(tester, ['Consultorio 5', 'Consultorio 6', 'Consultorio 12']);
  });

  testWidgets('cambiar el orden respeta el filtro ya buscado', (tester) async {
    final search = await _pump(tester);
    await _enter(tester, 'clinic-filter-location', 'piso');
    await _tap(tester, 'clinic-filter-search');
    expect(search.calls, 2);
    _expectNames(tester, ['Consultorio 5', 'Consultorio 6']);

    await _select(tester, 'clinic-filter-order', 'Ubicación');

    expect(search.calls, 3);
    expect(search.queries.last.toQueryParameters(), {
      'ubicacion': 'piso',
      'orden': 'ubicacion',
    });
    _expectNames(tester, ['Consultorio 5', 'Consultorio 6']);
  });

  testWidgets('Descendente invierte por nombre sin consultar de nuevo', (
    tester,
  ) async {
    final search = await _pump(tester);
    expect(find.text('Ascendente'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await _tap(tester, 'clinic-filter-direction');

    expect(search.calls, 1);
    expect(find.text('Descendente'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    _expectNames(tester, ['Consultorio 12', 'Consultorio 6', 'Consultorio 5']);
  });

  testWidgets('Ubicación descendente invierte sin consultar de nuevo', (
    tester,
  ) async {
    final search = await _pump(tester);
    await _select(tester, 'clinic-filter-order', 'Ubicación');
    expect(search.calls, 2);

    await _tap(tester, 'clinic-filter-direction');

    expect(search.calls, 2);
    _expectNames(tester, ['Consultorio 12', 'Consultorio 6', 'Consultorio 5']);
  });

  testWidgets('cambiar el orden conserva el sentido', (tester) async {
    final search = await _pump(tester);
    await _tap(tester, 'clinic-filter-direction');
    expect(search.calls, 1);

    await _select(tester, 'clinic-filter-order', 'Ubicación');

    expect(search.calls, 2);
    expect(find.text('Descendente'), findsOneWidget);
    _expectNames(tester, ['Consultorio 12', 'Consultorio 6', 'Consultorio 5']);
  });

  testWidgets('Limpiar vuelve a nombre ascendente y a las tres filas', (
    tester,
  ) async {
    final search = await _pump(tester);
    await _select(tester, 'clinic-filter-order', 'Ubicación');
    await _tap(tester, 'clinic-filter-direction');
    await _enter(tester, 'clinic-filter-name', '12');

    await _tap(tester, 'clinic-filter-clear');

    expect(search.queries.last.toQueryParameters(), isEmpty);
    expect(find.text('Ascendente'), findsOneWidget);
    expect(
      tester
          .state<FormFieldState<ClinicOrder>>(
            find.byKey(const Key('clinic-filter-order')),
          )
          .value,
      ClinicOrder.name,
    );
    _expectNames(tester, ['Consultorio 5', 'Consultorio 6', 'Consultorio 12']);
  });

  testWidgets('Enter en ubicación busca y Enter en nombre no', (tester) async {
    final search = await _pump(tester);
    await _enter(tester, 'clinic-filter-name', '12');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await _settle(tester);
    expect(search.calls, 1);

    await _enter(tester, 'clinic-filter-name', '');
    await _enter(tester, 'clinic-filter-location', 'piso');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settle(tester);

    expect(search.calls, 2);
    expect(search.queries.last.toQueryParameters(), {'ubicacion': 'piso'});
    _expectNames(tester, ['Consultorio 5', 'Consultorio 6']);
  });

  testWidgets('con 3, 7 y 12 el nombre ascendente es 3, 7, 12', (tester) async {
    await _pump(tester, clinics: _numberedClinics);

    _expectNames(tester, ['Consultorio 3', 'Consultorio 7', 'Consultorio 12']);
  });

  testWidgets('con 3, 7 y 12 Descendente es 12, 7, 3', (tester) async {
    await _pump(tester, clinics: _numberedClinics);

    await _tap(tester, 'clinic-filter-direction');

    _expectNames(tester, ['Consultorio 12', 'Consultorio 7', 'Consultorio 3']);
  });

  testWidgets('Ubicación ordena Piso 2, Piso 10 y Planta baja', (tester) async {
    await _pump(tester, clinics: _locationClinics);

    await _select(tester, 'clinic-filter-order', 'Ubicación');

    _expectNames(tester, ['Piso 2', 'Piso 10', 'Planta baja']);
    _expectNames(tester, ['Consultorio 9', 'Consultorio 8', 'Consultorio 4']);
  });

  testWidgets('Ubicación descendente invierte Piso 2, Piso 10 y Planta baja', (
    tester,
  ) async {
    await _pump(tester, clinics: _locationClinics);

    await _select(tester, 'clinic-filter-order', 'Ubicación');
    await _tap(tester, 'clinic-filter-direction');

    _expectNames(tester, ['Planta baja', 'Piso 10', 'Piso 2']);
    _expectNames(tester, ['Consultorio 4', 'Consultorio 8', 'Consultorio 9']);
  });

  testWidgets('Ubicación con tildes queda Ático, Piso 1, Zona', (tester) async {
    await _pump(tester, clinics: _accentLocations);

    await _select(tester, 'clinic-filter-order', 'Ubicación');

    _expectNames(tester, ['Ático', 'Piso 1', 'Zona']);
    _expectNames(tester, ['Consultorio 8', 'Consultorio 4', 'Consultorio 9']);
  });

  testWidgets('Ubicación descendente con tildes invierte Ático, Piso 1, Zona', (
    tester,
  ) async {
    await _pump(tester, clinics: _accentLocations);

    await _select(tester, 'clinic-filter-order', 'Ubicación');
    await _tap(tester, 'clinic-filter-direction');

    _expectNames(tester, ['Zona', 'Piso 1', 'Ático']);
    _expectNames(tester, ['Consultorio 9', 'Consultorio 4', 'Consultorio 8']);
  });

  testWidgets('un alta en Descendente conserva el sentido y el orden', (
    tester,
  ) async {
    final db = FakeAdminDatabase();
    db.clinics
      ..clear()
      ..addAll(_numberedClinics);
    await pumpAdminScreens(
      tester,
      initialLocation: kClinicsPath,
      routes: [
        GoRoute(
          path: kClinicsPath,
          builder: (_, _) => const ClinicsScreen(),
          routes: [
            GoRoute(path: 'nuevo', builder: (_, _) => const NewClinicScreen()),
          ],
        ),
      ],
      overrides: [
        clinicRepositoryProvider.overrideWith(
          (ref) async => FakeClinicRepository(db, latency: Duration.zero),
        ),
        clinicSearchRepositoryProvider.overrideWith(
          (ref) async => FakeClinicSearchRepository(db, latency: Duration.zero),
        ),
      ],
    );

    await _tap(tester, 'clinic-filter-direction');
    expect(find.text('Descendente'), findsOneWidget);

    await tester.tap(find.text('Nuevo consultorio'));
    await tester.pumpAndSettle();
    final formFields = find.descendant(
      of: find.byType(Form),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(formFields.at(0), 'Consultorio 20');
    await tester.enterText(formFields.at(1), 'Piso 9');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar consultorio'));
    await tester.pumpAndSettle();

    expect(find.text('Descendente'), findsOneWidget);
    _expectNames(tester, [
      'Consultorio 20',
      'Consultorio 12',
      'Consultorio 7',
      'Consultorio 3',
    ]);
  });

  testWidgets('a 320 px el botón de sentido no desborda', (tester) async {
    await _pump(tester, size: const Size(320, 800));

    expect(find.byKey(const Key('clinic-filter-direction')), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Scaffold)).width, 320);
  });

  testWidgets('a 320 px con texto 1.3 el botón de sentido no desborda', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(320, 900),
      textScaler: TextScaler.linear(1.3),
    );

    final button = find.byKey(const Key('clinic-filter-direction'));
    expect(button, findsOneWidget);
    await tester.ensureVisible(button);
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
