import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/screens/specialties_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

// Orden deliberadamente diferente del alfabético: la pantalla no debe reordenar.
const _items = [
  Specialty(id: 1, name: 'Medicina General', requiresReferral: false),
  Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
];

class _Repository implements SpecialtySearchRepository {
  final List<SpecialtyFilters> queries = [];
  List<Specialty> items = _items;
  Object? error;

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) async {
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
      specialtySearchRepositoryProvider.overrideWith((ref) async => repository),
      // Evita HTTP mientras la pantalla anterior aún observa el catálogo.
      // La integración correcta debe consultar el repositorio de búsqueda.
      specialtiesProvider.overrideWith((ref) async => _items),
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
        home: const SpecialtiesScreen(),
      ),
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
      (widget) => widget is Semantics &&
          widget.properties.role == SemanticsRole.menuItem,
    ),
  );
  expect(menuItem, findsOneWidget);
  final option = find.descendant(
    of: menuItem,
    matching: find.byType(InkWell),
  ).hitTestable();
  expect(option, findsOneWidget);
  await tester.tap(option);
  await tester.pump();
  await _settle(tester);
}

Future<void> _enterName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('specialty-filter-name')), name);
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
      for (final name in ['Medicina General', 'Cardiología']) {
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
      await _enterName(tester, 'inexistente');
      await _tap(tester, 'specialty-filter-search');

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      expect(repository.queries, hasLength(2));
      expect(repository.queries.last.toQueryParameters(), {
        'nombre': 'inexistente',
      });
      final empty = find.byKey(const Key('specialty-filter-empty'));
      expect(empty, findsOneWidget);
      expect(find.text('No hay especialidades que coincidan.'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      await tester.ensureVisible(empty);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(empty.hitTestable(), findsOneWidget);
    });

    testWidgets('error de consulta con Reintentar no desborda', (tester) async {
      final repository = _Repository()
        ..error = const SpecialtySearchException(
          SpecialtySearchFailure.other,
          'Error de consulta de prueba.',
        );
      await _pump(tester, repository, size: size);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      expect(repository.queries, hasLength(1));
      expect(
        find.text('No pudimos cargar las especialidades. Intentá de nuevo.'),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsNothing);
      final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
      expect(retry, findsOneWidget);
      await tester.ensureVisible(retry);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(retry.hitTestable(), findsOneWidget);
      expect(tester.widget<OutlinedButton>(retry).onPressed, isNotNull);
    });
  });

  testWidgets('al abrir ejecuta una búsqueda con filtros predeterminados',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);

    expect(repository.queries, hasLength(1));
    final query = repository.queries.single;
    expect(query.name, isNull);
    expect(query.requiresReferral, isNull);
    expect(query.order, SpecialtyOrder.name);
    expect(query.toQueryParameters(), isEmpty);
  });

  testWidgets('muestra las especialidades en el orden recibido', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);

    expect(find.text('Medicina General'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Medicina General')).dy,
      lessThan(tester.getTopLeft(find.text('Cardiología')).dy),
    );
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('Libre')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(ListTile), matching: find.text('Requiere pase')),
      findsOneWidget,
    );
  });

  testWidgets('escribir un nombre no consulta automáticamente', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);

    await _enterName(tester, 'cardio');
    await _settle(tester);

    expect(repository.queries, hasLength(1));
    expect(repository.queries.single.toQueryParameters(), isEmpty);
  });

  testWidgets('Buscar consulta con el nombre ingresado', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enterName(tester, 'cardio');

    await _tap(tester, 'specialty-filter-search');

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.toQueryParameters(), {'nombre': 'cardio'});
  });

  testWidgets('Limpiar restablece controles y consulta sin parámetros',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enterName(tester, 'cardio');
    await _select(tester, 'specialty-filter-referral', 'Sí');
    await _select(tester, 'specialty-filter-order', 'Fecha de alta');
    await _tap(tester, 'specialty-filter-search');
    expect(repository.queries, hasLength(2));

    await _tap(tester, 'specialty-filter-clear');

    expect(repository.queries, hasLength(3));
    expect(repository.queries.last.toQueryParameters(), isEmpty);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('specialty-filter-name')))
          .controller!.text,
      isEmpty,
    );
    expect(
      tester.state<FormFieldState<bool>>(
        find.byKey(const Key('specialty-filter-referral')),
      ).value,
      isNull,
    );
    expect(
      tester.state<FormFieldState<SpecialtyOrder>>(
        find.byKey(const Key('specialty-filter-order')),
      ).value,
      SpecialtyOrder.name,
    );
  });

  testWidgets('Sí y Fecha de alta envían exactamente los filtros seleccionados',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _select(tester, 'specialty-filter-referral', 'Sí');
    await _select(tester, 'specialty-filter-order', 'Fecha de alta');
    expect(repository.queries, hasLength(1));

    await _tap(tester, 'specialty-filter-search');

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.toQueryParameters(), {
      'requierePase': true,
      'orden': 'fechaAlta',
    });
  });

  testWidgets('un nombre de solo espacios no se envía', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enterName(tester, '   ');

    await _tap(tester, 'specialty-filter-search');

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.toQueryParameters(), isEmpty);
  });

  testWidgets('sin coincidencias con filtros muestra el mensaje específico',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    repository.items = [];
    await _enterName(tester, 'inexistente');

    await _tap(tester, 'specialty-filter-search');

    expect(
      find.byKey(const Key('specialty-filter-empty')),
      findsOneWidget,
    );
    expect(find.text('No hay especialidades que coincidan.'), findsOneWidget);
    expect(find.text('Todavía no hay especialidades registradas.'), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('sin filtros ni especialidades conserva el mensaje original',
      (tester) async {
    final repository = _Repository()..items = [];
    await _pump(tester, repository);

    expect(find.text('Todavía no hay especialidades registradas.'), findsOneWidget);
    expect(find.byKey(const Key('specialty-filter-empty')), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('400 VALIDACION muestra el mensaje del servidor', (tester) async {
    final repository = _Repository()
      ..error = const SpecialtySearchException(
        SpecialtySearchFailure.validation,
        'El nombre no puede superar los 120 caracteres.',
      );
    await _pump(tester, repository);

    expect(find.text('El nombre no puede superar los 120 caracteres.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('401 muestra el mensaje de sesión requerido', (tester) async {
    final repository = _Repository()
      ..error = const SpecialtySearchException(
        SpecialtySearchFailure.unauthenticated,
        'Se requiere autenticación.',
      );
    await _pump(tester, repository);

    expect(find.text('Tu sesión venció. Iniciá sesión nuevamente.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('403 muestra el mensaje de permiso requerido', (tester) async {
    final repository = _Repository()
      ..error = const SpecialtySearchException(
        SpecialtySearchFailure.forbidden,
        'Acceso denegado.',
      );
    await _pump(tester, repository);

    expect(
      find.text('Tu cuenta no tiene permiso para ver las especialidades.'),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('Reintentar repite los filtros aplicados y no los controles editados',
      (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    repository.error = const SpecialtySearchException(
      SpecialtySearchFailure.validation,
      'No se pudo completar la búsqueda de prueba.',
    );
    await _enterName(tester, 'cardio');
    await _select(tester, 'specialty-filter-referral', 'Sí');
    await _select(tester, 'specialty-filter-order', 'Fecha de alta');
    await _tap(tester, 'specialty-filter-search');
    expect(repository.queries, hasLength(2));
    expect(find.text('No se pudo completar la búsqueda de prueba.'), findsOneWidget);

    await _enterName(tester, 'pedi');
    await _select(tester, 'specialty-filter-referral', 'No');
    await _select(tester, 'specialty-filter-order', 'Nombre');
    expect(repository.queries, hasLength(2));
    repository.error = null;
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await _settle(tester);

    expect(repository.queries, hasLength(3));
    expect(repository.queries.last.toQueryParameters(), {
      'nombre': 'cardio',
      'requierePase': true,
      'orden': 'fechaAlta',
    });
    expect(find.text('Medicina General'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.text('No se pudo completar la búsqueda de prueba.'), findsNothing);
  });
}
