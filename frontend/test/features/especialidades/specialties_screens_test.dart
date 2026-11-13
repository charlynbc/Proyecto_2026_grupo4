import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/forms/submit_state.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/providers/create_specialty_controller.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_filters_controller.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/screens/new_specialty_screen.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/error_text_fit.dart';
import '../../helpers/load_roboto.dart';
import '../../helpers/pump_admin.dart';

Future<GoRouter> _pump(
  WidgetTester tester,
  String initial, {
  Size size = const Size(900, 1800),
}) {
  final db = FakeAdminDatabase();
  return pumpAdminScreens(
    tester,
    size: size,
    initialLocation: initial,
    routes: [
      GoRoute(
        path: kSpecialtiesPath,
        builder: (_, _) => const SpecialtiesScreen(),
      ),
      GoRoute(
        path: kNewSpecialtyPath,
        builder: (_, _) => const NewSpecialtyScreen(),
      ),
    ],
    overrides: [
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(db, latency: Duration.zero),
      ),
      specialtySearchRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtySearchRepository(db, latency: Duration.zero),
      ),
    ],
  );
}

Finder get _name => find.byType(TextFormField);
Finder get _save => find.widgetWithText(FilledButton, 'Guardar especialidad');

class _RecordingCatalog extends FakeSpecialtyRepository {
  _RecordingCatalog(super.db) : super(latency: Duration.zero);

  int listCalls = 0;

  @override
  Future<List<Specialty>> list() {
    listCalls++;
    return super.list();
  }
}

class _RecordingSearch extends FakeSpecialtySearchRepository {
  _RecordingSearch(super.db) : super(latency: Duration.zero);

  final List<SpecialtyFilters> queries = [];

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) {
    queries.add(filters);
    return super.search(filters);
  }
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('el listado muestra cada especialidad con "Requiere pase" o '
      '"Libre"', (tester) async {
    await _pump(tester, kSpecialtiesPath);

    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.text('Medicina General'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('Requiere pase')),
      findsNWidgets(2),
    );
    expect(find.text('Libre'), findsOneWidget);
  });

  testWidgets('"Nueva especialidad" lleva al formulario', (tester) async {
    final router = await _pump(tester, kSpecialtiesPath);

    await tester.tap(find.text('Nueva especialidad'));
    await tester.pumpAndSettle();

    expect(currentLocation(router), kNewSpecialtyPath);
  });

  testWidgets('sin nombre no se guarda y se pide completarlo', (tester) async {
    final router = await _pump(tester, kNewSpecialtyPath);

    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(find.text('Ingresá el nombre de la especialidad.'), findsOneWidget);
    expect(currentLocation(router), kNewSpecialtyPath);
  });

  for (final scale in [1.0, 1.15]) {
    testWidgets('a 320 px con el texto al $scale el mensaje del nombre vacío '
        'se lee entero', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, kNewSpecialtyPath, size: const Size(320, 900));

      await tester.tap(_save);
      await tester.pumpAndSettle();

      expectErrorFits(tester, 'Ingresá el nombre de la especialidad.');
    });
  }

  testWidgets('un nombre repetido muestra el aviso y conserva lo escrito', (
    tester,
  ) async {
    final router = await _pump(tester, kNewSpecialtyPath);

    await tester.enterText(_name, 'CARDIOLOGÍA');
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe una especialidad registrada con ese nombre.'),
      findsOneWidget,
    );
    expect(find.text('CARDIOLOGÍA'), findsOneWidget);
    expect(currentLocation(router), kNewSpecialtyPath);
  });

  testWidgets('el alta correcta vuelve al listado con la nueva especialidad', (
    tester,
  ) async {
    final router = await _pump(tester, kNewSpecialtyPath);

    await tester.enterText(_name, 'Neurología');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(currentLocation(router), kSpecialtiesPath);
    expect(find.text('Especialidad registrada.'), findsOneWidget);
    expect(find.text('Neurología'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('Requiere pase')),
      findsNWidgets(3),
    );
  });

  group('actualización de listados después del alta', () {
    late ProviderContainer container;
    late _RecordingCatalog catalog;
    late _RecordingSearch search;

    setUp(() {
      final db = FakeAdminDatabase();
      catalog = _RecordingCatalog(db);
      search = _RecordingSearch(db);
      container = ProviderContainer(
        overrides: [
          specialtyRepositoryProvider.overrideWith((ref) async => catalog),
          specialtySearchRepositoryProvider.overrideWith((ref) async => search),
        ],
      );
      addTearDown(container.dispose);
      // Mantiene las listas observadas para detectar la invalidación, sin que
      // desmontar una pantalla y crear otra oculte la falta de actualización.
      container.listen(specialtySearchProvider, (_, _) {}, onError: (_, _) {});
      container.listen(specialtiesProvider, (_, _) {}, onError: (_, _) {});
      container.listen(createSpecialtyControllerProvider, (_, _) {});
    });

    Future<void> loadInitial() async {
      await container.read(specialtySearchProvider.future);
      await container.read(specialtiesProvider.future);
    }

    Future<void> create(String name, {bool requiresReferral = false}) =>
        container.read(createSpecialtyControllerProvider.notifier).submit(
          name: name,
          requiresReferral: requiresReferral,
        );

    test('un alta exitosa invalida y actualiza el listado de búsqueda', () async {
      await loadInitial();
      expect(search.queries, hasLength(1));

      await create('Neurología');
      await container.pump();
      final items = await container.read(specialtySearchProvider.future);

      expect(search.queries, hasLength(2));
      expect(search.queries.last.toQueryParameters(), isEmpty);
      expect(items.map((item) => item.name), [
        'Cardiología', 'Dermatología', 'Medicina General', 'Neurología',
      ]);
      expect(container.read(createSpecialtyControllerProvider).status, SubmitStatus.done);
    });

    test('el alta recarga la búsqueda respetando todos los filtros aplicados',
        () async {
      await loadInitial();
      container.read(specialtyFiltersControllerProvider.notifier).apply(
        name: 'neuro',
        requiresReferral: true,
        order: SpecialtyOrder.createdAt,
      );
      await container.pump();
      expect(await container.read(specialtySearchProvider.future), isEmpty);
      expect(search.queries, hasLength(2));

      await create('Neurología', requiresReferral: true);
      await container.pump();
      final items = await container.read(specialtySearchProvider.future);

      expect(search.queries, hasLength(3));
      expect(search.queries.last.toQueryParameters(), {
        'nombre': 'neuro', 'requierePase': true, 'orden': 'fechaAlta',
      });
      expect(items, hasLength(1));
      expect(items.single.name, 'Neurología');
      expect(items.single.requiresReferral, isTrue);
      final applied = container.read(specialtyFiltersControllerProvider);
      expect(applied.name, 'neuro');
      expect(applied.requiresReferral, isTrue);
      expect(applied.order, SpecialtyOrder.createdAt);
    });

    test('el alta sigue invalidando y actualizando el catálogo compartido',
        () async {
      await loadInitial();
      expect(catalog.listCalls, 1);

      await create('Neurología');
      await container.pump();
      final items = await container.read(specialtiesProvider.future);

      expect(catalog.listCalls, 2);
      expect(items.map((item) => item.name), [
        'Cardiología', 'Dermatología', 'Medicina General', 'Neurología',
      ]);
    });

    test('un alta fallida no invalida la búsqueda ni el catálogo compartido',
        () async {
      await loadInitial();

      // El fake existente rechaza el duplicado sin alterar la base.
      await create('CARDIOLOGÍA');
      await container.pump();
      final filtered = await container.read(specialtySearchProvider.future);
      final shared = await container.read(specialtiesProvider.future);

      expect(container.read(createSpecialtyControllerProvider).status, SubmitStatus.error);
      expect(search.queries, hasLength(1));
      expect(catalog.listCalls, 1);
      expect(filtered.map((item) => item.name), [
        'Cardiología', 'Dermatología', 'Medicina General',
      ]);
      expect(shared.map((item) => item.name), [
        'Cardiología', 'Dermatología', 'Medicina General',
      ]);
    });
  });
}
