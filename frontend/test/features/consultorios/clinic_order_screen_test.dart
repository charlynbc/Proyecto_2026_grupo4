import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/screens/clinics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

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

Future<_Search> _pump(
  WidgetTester tester, {
  Size size = const Size(900, 1400),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = FakeAdminDatabase();
  db.clinics
    ..clear()
    ..addAll(const [
      Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2, ala norte'),
      Clinic(id: 6, name: 'Consultorio 6', location: 'Piso 2, ala sur'),
      Clinic(id: 12, name: 'Consultorio 12', location: 'Planta baja'),
    ]);
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

  testWidgets('al abrir ordena por nombre: 12, 5 y 6', (tester) async {
    final search = await _pump(tester);

    expect(search.calls, 1);
    expect(search.queries.single.toQueryParameters(), isEmpty);
    _expectNames(tester, ['Consultorio 12', 'Consultorio 5', 'Consultorio 6']);
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
    _expectNames(tester, ['Consultorio 6', 'Consultorio 5', 'Consultorio 12']);
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
    _expectNames(tester, ['Consultorio 12', 'Consultorio 5', 'Consultorio 6']);
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
