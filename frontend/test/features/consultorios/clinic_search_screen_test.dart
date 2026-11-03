import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_search_repository.dart';
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

// Orden distinto del alfabético: la pantalla no debe reordenar.
const _items = [
  Clinic(id: 6, name: 'Consultorio 6', location: 'Piso 2, ala sur'),
  Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2, ala norte'),
];

class _Repository implements ClinicSearchRepository {
  final List<ClinicFilters> queries = [];
  List<Clinic> items = _items;
  Object? error;

  @override
  Future<List<Clinic>> search(ClinicFilters filters) async {
    queries.add(filters);
    if (error != null) throw error!;
    return items;
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(900, 1100),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      clinicSearchRepositoryProvider.overrideWith((ref) async => repository),
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
      child: MaterialApp(theme: appTheme, home: const ClinicsScreen()),
    ),
  );
  await _settle(tester);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);

  group('pantalla completa a 320 px con Roboto', () {
    const size = Size(320, 640);

    testWidgets('listado con resultados no desborda', (tester) async {
      final repository = _Repository();
      await _pump(tester, repository, size: size);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      expect(repository.queries, hasLength(1));
      expect(find.byType(ListTile), findsNWidgets(2));
      for (final name in ['Consultorio 6', 'Consultorio 5']) {
        final item = find.text(name);
        expect(item, findsOneWidget);
        await tester.ensureVisible(item);
        await _settle(tester);
        expect(tester.takeException(), isNull);
        expect(item.hitTestable(), findsOneWidget);
      }
    });

    testWidgets('búsqueda sin coincidencias no desborda', (tester) async {
      final repository = _Repository();
      await _pump(tester, repository, size: size);
      expect(tester.takeException(), isNull);
      repository.items = [];
      await _enter(tester, 'clinic-filter-name', 'inexistente');
      await _tap(tester, 'clinic-filter-search');

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      expect(repository.queries, hasLength(2));
      expect(repository.queries.last.toQueryParameters(), {
        'nombre': 'inexistente',
      });
      final empty = find.byKey(const Key('clinic-filter-empty'));
      expect(empty, findsOneWidget);
      expect(find.text('No hay consultorios que coincidan.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      await tester.ensureVisible(empty);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(empty.hitTestable(), findsOneWidget);
    });

    testWidgets('error de consulta con Reintentar no desborda', (tester) async {
      final repository = _Repository()
        ..error = const ClinicSearchException(
          ClinicSearchFailure.other,
          'Error de consulta de prueba.',
        );
      await _pump(tester, repository, size: size);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      expect(repository.queries, hasLength(1));
      expect(
        find.text('No pudimos cargar los consultorios. Intentá de nuevo.'),
        findsOneWidget,
      );
      final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(retry.hitTestable(), findsOneWidget);
      expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
    });
  });

  testWidgets('al abrir busca una vez con los filtros por defecto', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);

    expect(repository.queries, hasLength(1));
    final query = repository.queries.single;
    expect(query.name, isNull);
    expect(query.location, isNull);
    expect(query.order, ClinicOrder.name);
    expect(query.toQueryParameters(), isEmpty);
  });

  testWidgets('muestra las filas en el orden del servidor', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);

    expect(find.text('Consultorio 6'), findsOneWidget);
    expect(find.text('Piso 2, ala sur'), findsOneWidget);
    expect(find.text('Consultorio 5'), findsOneWidget);
    expect(find.text('Piso 2, ala norte'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Consultorio 6')).dy,
      lessThan(tester.getTopLeft(find.text('Consultorio 5')).dy),
    );
  });

  testWidgets('escribir 5 no busca hasta tocar Buscar', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);

    await _enter(tester, 'clinic-filter-name', '5');
    await _settle(tester);

    expect(repository.queries, hasLength(1));
    expect(repository.queries.single.toQueryParameters(), isEmpty);
  });

  testWidgets('Buscar envía el nombre 5', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enter(tester, 'clinic-filter-name', '5');

    await _tap(tester, 'clinic-filter-search');

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.toQueryParameters(), {'nombre': '5'});
  });

  testWidgets('Limpiar vuelve a buscar sin filtros', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enter(tester, 'clinic-filter-name', '5');
    await _enter(tester, 'clinic-filter-location', 'norte');
    await _select(tester, 'clinic-filter-order', 'Ubicación');
    await _tap(tester, 'clinic-filter-search');
    expect(repository.queries, hasLength(2));

    await _tap(tester, 'clinic-filter-clear');

    expect(repository.queries, hasLength(3));
    expect(repository.queries.last.toQueryParameters(), isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('clinic-filter-name')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('clinic-filter-location')),
          )
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .state<FormFieldState<ClinicOrder>>(
            find.byKey(const Key('clinic-filter-order')),
          )
          .value,
      ClinicOrder.name,
    );
  });

  testWidgets('ubicación y orden Ubicación se envían juntos', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enter(tester, 'clinic-filter-location', 'norte');
    await _select(tester, 'clinic-filter-order', 'Ubicación');
    expect(repository.queries, hasLength(1));

    await _tap(tester, 'clinic-filter-search');

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.toQueryParameters(), {
      'ubicacion': 'norte',
      'orden': 'ubicacion',
    });
  });

  testWidgets('un texto de solo espacios no se envía', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enter(tester, 'clinic-filter-name', '   ');
    await _enter(tester, 'clinic-filter-location', '   ');

    await _tap(tester, 'clinic-filter-search');

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.toQueryParameters(), isEmpty);
  });

  testWidgets('sin resultados muestra clinic-filter-empty', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    repository.items = [];
    await _enter(tester, 'clinic-filter-name', '9');

    await _tap(tester, 'clinic-filter-search');

    expect(find.byKey(const Key('clinic-filter-empty')), findsOneWidget);
    expect(find.text('No hay consultorios que coincidan.'), findsOneWidget);
    expect(
      find.text('Todavía no hay consultorios registrados.'),
      findsNothing,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('sin filtros y sin consultorios mantiene el mensaje de siempre', (
    tester,
  ) async {
    final repository = _Repository()..items = [];
    await _pump(tester, repository);

    expect(
      find.text('Todavía no hay consultorios registrados.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('clinic-filter-empty')), findsNothing);
  });

  testWidgets('un 400 muestra el mensaje del servidor', (tester) async {
    const message = 'La ubicación no puede superar los 200 caracteres.';
    final repository = _Repository()
      ..error = const ClinicSearchException(
        ClinicSearchFailure.validation,
        message,
      );
    await _pump(tester, repository);

    expect(find.text(message), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('un 401 avisa que la sesión venció', (tester) async {
    final repository = _Repository()
      ..error = const ClinicSearchException(
        ClinicSearchFailure.unauthenticated,
        'Se requiere autenticación.',
      );
    await _pump(tester, repository);

    expect(
      find.text('Tu sesión venció. Iniciá sesión nuevamente.'),
      findsOneWidget,
    );
  });

  testWidgets('un 403 avisa que no hay permiso', (tester) async {
    final repository = _Repository()
      ..error = const ClinicSearchException(
        ClinicSearchFailure.forbidden,
        'Acceso denegado.',
      );
    await _pump(tester, repository);

    expect(
      find.text('Tu cuenta no tiene permiso para ver los consultorios.'),
      findsOneWidget,
    );
  });

  testWidgets('Reintentar repite la última búsqueda con los mismos filtros', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);
    repository.error = const ClinicSearchException(
      ClinicSearchFailure.validation,
      'No se pudo completar la búsqueda de prueba.',
    );
    await _enter(tester, 'clinic-filter-name', '5');
    await _enter(tester, 'clinic-filter-location', 'norte');
    await _select(tester, 'clinic-filter-order', 'Ubicación');
    await _tap(tester, 'clinic-filter-search');
    expect(repository.queries, hasLength(2));
    expect(
      find.text('No se pudo completar la búsqueda de prueba.'),
      findsOneWidget,
    );

    await _enter(tester, 'clinic-filter-name', '12');
    await _select(tester, 'clinic-filter-order', 'Nombre');
    expect(repository.queries, hasLength(2));
    repository.error = null;
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await _settle(tester);

    expect(repository.queries, hasLength(3));
    expect(repository.queries.last.toQueryParameters(), {
      'nombre': '5',
      'ubicacion': 'norte',
      'orden': 'ubicacion',
    });
    expect(find.text('Consultorio 6'), findsOneWidget);
    expect(
      find.text('No se pudo completar la búsqueda de prueba.'),
      findsNothing,
    );
  });

  testWidgets(
    'un consultorio creado desde el formulario aparece al volver',
    (tester) async {
      final db = FakeAdminDatabase();
      final router = await pumpAdminScreens(
        tester,
        initialLocation: kClinicsPath,
        routes: [
          GoRoute(
            path: kClinicsPath,
            builder: (_, _) => const ClinicsScreen(),
            routes: [
              GoRoute(
                path: 'nuevo',
                builder: (_, _) => const NewClinicScreen(),
              ),
            ],
          ),
        ],
        overrides: [
          clinicRepositoryProvider.overrideWith(
            (ref) async => FakeClinicRepository(db, latency: Duration.zero),
          ),
          clinicSearchRepositoryProvider.overrideWith(
            (ref) async =>
                FakeClinicSearchRepository(db, latency: Duration.zero),
          ),
        ],
      );

      await _enter(tester, 'clinic-filter-location', 'piso 9');
      await _tap(tester, 'clinic-filter-search');
      expect(find.byKey(const Key('clinic-filter-empty')), findsOneWidget);

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

      expect(currentLocation(router), kClinicsPath);
      expect(find.text('Consultorio registrado.'), findsOneWidget);
      expect(find.text('Consultorio 20'), findsOneWidget);
      expect(find.text('Piso 9'), findsOneWidget);
      expect(find.text('Consultorio 3'), findsNothing);
    },
  );
}
