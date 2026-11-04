import 'dart:ui' show SemanticsRole;

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
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

class _FakeRepository extends _Repository {
  _FakeRepository({bool withNeurology = true}) {
    final db = FakeAdminDatabase();
    if (withNeurology) {
      db.specialties.add(
        Specialty(
          id: db.newSpecialtyId(),
          name: 'Neurología',
          requiresReferral: false,
        ),
      );
    }
    _delegate = FakeSpecialtySearchRepository(db, latency: Duration.zero);
  }

  late final FakeSpecialtySearchRepository _delegate;

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) {
    queries.add(filters);
    return _delegate.search(filters);
  }
}

Iterable<String> _displayedNames(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title! as Text).data!);

void _expectDirection(String label, IconData icon) {
  final button = find.byKey(const Key('specialty-filter-direction'));
  expect(button, findsOneWidget);
  expect(
    find.descendant(of: button, matching: find.text(label)),
    findsOneWidget,
  );
  expect(
    find.descendant(of: button, matching: find.byIcon(icon)),
    findsOneWidget,
  );
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
      child: MaterialApp(theme: appTheme, home: const SpecialtiesScreen()),
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

Future<void> _enterName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('specialty-filter-name')), name);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRoboto);

  group('orden inmediato y sentido en pantalla', () {
    testWidgets('Fecha de alta consulta inmediatamente sin pulsar Buscar', (
      tester,
    ) async {
      final repository = _FakeRepository();
      await _pump(tester, repository);
      expect(repository.queries, hasLength(1));
      expect(_displayedNames(tester), [
        'Cardiología',
        'Dermatología',
        'Medicina General',
        'Neurología',
      ]);

      await _select(tester, 'specialty-filter-order', 'Fecha de alta');

      expect(repository.queries, hasLength(2));
      expect(repository.queries.last.toQueryParameters(), {
        'orden': 'fechaAlta',
      });
      expect(_displayedNames(tester), [
        'Medicina General',
        'Cardiología',
        'Dermatología',
        'Neurología',
      ]);
    });

    testWidgets(
      'orden inmediato no aplica texto ni pase pendientes de Buscar',
      (tester) async {
        final repository = _FakeRepository();
        await _pump(tester, repository);
        await _enterName(tester, 'cardio');
        await _select(tester, 'specialty-filter-referral', 'Sí');
        expect(repository.queries, hasLength(1));

        await _select(tester, 'specialty-filter-order', 'Fecha de alta');

        expect(repository.queries, hasLength(2));
        expect(repository.queries.last.toQueryParameters(), {
          'orden': 'fechaAlta',
        });
        expect(_displayedNames(tester), [
          'Medicina General',
          'Cardiología',
          'Dermatología',
          'Neurología',
        ]);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('specialty-filter-name')),
              )
              .controller!
              .text,
          'cardio',
        );
        expect(
          tester
              .state<FormFieldState<bool>>(
                find.byKey(const Key('specialty-filter-referral')),
              )
              .value,
          isTrue,
        );
      },
    );

    testWidgets(
      'Buscar conserva orden y sentido y el siguiente orden conserva filtros',
      (tester) async {
        final repository = _FakeRepository();
        await _pump(tester, repository);
        await _select(tester, 'specialty-filter-order', 'Fecha de alta');
        await _tap(tester, 'specialty-filter-direction');
        expect(repository.queries, hasLength(2));
        await _enterName(tester, 'logía');
        await _select(tester, 'specialty-filter-referral', 'Sí');
        expect(repository.queries, hasLength(2));

        await _tap(tester, 'specialty-filter-search');

        expect(repository.queries, hasLength(3));
        expect(repository.queries.last.toQueryParameters(), {
          'nombre': 'logía',
          'requierePase': true,
          'orden': 'fechaAlta',
        });
        expect(_displayedNames(tester), ['Dermatología', 'Cardiología']);
        _expectDirection('Descendente', Icons.arrow_downward);

        await _enterName(tester, 'cardio');
        await _select(tester, 'specialty-filter-referral', 'No');
        await _select(tester, 'specialty-filter-order', 'Nombre');

        expect(repository.queries, hasLength(4));
        expect(repository.queries.last.toQueryParameters(), {
          'nombre': 'logía',
          'requierePase': true,
        });
        expect(_displayedNames(tester), ['Dermatología', 'Cardiología']);
        _expectDirection('Descendente', Icons.arrow_downward);
      },
    );

    testWidgets(
      'Nombre alterna sentido texto e icono sin consultas adicionales',
      (tester) async {
        final repository = _FakeRepository();
        await _pump(tester, repository);
        _expectDirection('Ascendente', Icons.arrow_upward);
        expect(_displayedNames(tester), [
          'Cardiología',
          'Dermatología',
          'Medicina General',
          'Neurología',
        ]);

        await _tap(tester, 'specialty-filter-direction');

        _expectDirection('Descendente', Icons.arrow_downward);
        expect(repository.queries, hasLength(1));
        expect(_displayedNames(tester), [
          'Neurología',
          'Medicina General',
          'Dermatología',
          'Cardiología',
        ]);

        await _tap(tester, 'specialty-filter-direction');

        _expectDirection('Ascendente', Icons.arrow_upward);
        expect(repository.queries, hasLength(1));
        expect(_displayedNames(tester), [
          'Cardiología',
          'Dermatología',
          'Medicina General',
          'Neurología',
        ]);
      },
    );

    testWidgets(
      'Fecha de alta invierte sin consultar y conserva sentido al cambiar criterio',
      (tester) async {
        final repository = _FakeRepository();
        await _pump(tester, repository);
        await _select(tester, 'specialty-filter-order', 'Fecha de alta');
        expect(repository.queries, hasLength(2));

        await _tap(tester, 'specialty-filter-direction');

        expect(repository.queries, hasLength(2));
        expect(_displayedNames(tester), [
          'Neurología',
          'Dermatología',
          'Cardiología',
          'Medicina General',
        ]);
        _expectDirection('Descendente', Icons.arrow_downward);

        await _select(tester, 'specialty-filter-order', 'Nombre');

        expect(repository.queries, hasLength(3));
        expect(
          repository.queries.last.toQueryParameters(),
          <String, dynamic>{},
        );
        _expectDirection('Descendente', Icons.arrow_downward);
        expect(_displayedNames(tester), [
          'Neurología',
          'Medicina General',
          'Dermatología',
          'Cardiología',
        ]);
      },
    );

    testWidgets(
      'Limpiar restaura controles sentido y tres filas con una sola recarga',
      (tester) async {
        final repository = _FakeRepository(withNeurology: false);
        await _pump(tester, repository);
        await _select(tester, 'specialty-filter-order', 'Fecha de alta');
        await _tap(tester, 'specialty-filter-direction');
        await _enterName(tester, 'logía');
        await _select(tester, 'specialty-filter-referral', 'Sí');
        await _tap(tester, 'specialty-filter-search');
        expect(repository.queries, hasLength(3));
        expect(_displayedNames(tester), ['Dermatología', 'Cardiología']);

        await _tap(tester, 'specialty-filter-clear');

        expect(repository.queries, hasLength(4));
        expect(
          repository.queries.last.toQueryParameters(),
          <String, dynamic>{},
        );
        expect(_displayedNames(tester), [
          'Cardiología',
          'Dermatología',
          'Medicina General',
        ]);
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('specialty-filter-name')),
              )
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .state<FormFieldState<bool>>(
                find.byKey(const Key('specialty-filter-referral')),
              )
              .value,
          isNull,
        );
        expect(
          tester
              .state<FormFieldState<SpecialtyOrder>>(
                find.byKey(const Key('specialty-filter-order')),
              )
              .value,
          SpecialtyOrder.name,
        );
        _expectDirection('Ascendente', Icons.arrow_upward);
        await _settle(tester);
        expect(repository.queries, hasLength(4));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Limpiar estando sin filtros recarga una sola vez', (
      tester,
    ) async {
      final repository = _FakeRepository();
      await _pump(tester, repository);
      await _tap(tester, 'specialty-filter-direction');
      expect(repository.queries, hasLength(1));

      await _tap(tester, 'specialty-filter-clear');

      expect(repository.queries, hasLength(2));
      _expectDirection('Ascendente', Icons.arrow_upward);
      expect(_displayedNames(tester), [
        'Cardiología',
        'Dermatología',
        'Medicina General',
        'Neurología',
      ]);
    });

    testWidgets('a 320 px con Roboto el sentido es accesible y no desborda', (
      tester,
    ) async {
      final repository = _FakeRepository();
      await _pump(tester, repository, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Scaffold)).width, 320);
      _expectDirection('Ascendente', Icons.arrow_upward);

      await _tap(tester, 'specialty-filter-direction');
      expect(tester.takeException(), isNull);
      _expectDirection('Descendente', Icons.arrow_downward);
      expect(repository.queries, hasLength(1));
      expect(_displayedNames(tester), [
        'Neurología',
        'Medicina General',
        'Dermatología',
        'Cardiología',
      ]);
      await _select(tester, 'specialty-filter-order', 'Fecha de alta');
      expect(tester.takeException(), isNull);
      expect(repository.queries, hasLength(2));
      expect(_displayedNames(tester), [
        'Neurología',
        'Dermatología',
        'Cardiología',
        'Medicina General',
      ]);
      final direction = find.byKey(const Key('specialty-filter-direction'));
      await tester.ensureVisible(direction);
      await _settle(tester);
      expect(direction.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

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

  testWidgets('al abrir ejecuta una búsqueda con filtros predeterminados', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);

    expect(repository.queries, hasLength(1));
    final query = repository.queries.single;
    expect(query.name, isNull);
    expect(query.requiresReferral, isNull);
    expect(query.order, SpecialtyOrder.name);
    expect(query.toQueryParameters(), isEmpty);
  });

  testWidgets('muestra las especialidades en el orden recibido', (
    tester,
  ) async {
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
      find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Requiere pase'),
      ),
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

  testWidgets('Limpiar restablece controles y consulta sin parámetros', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enterName(tester, 'cardio');
    await _select(tester, 'specialty-filter-referral', 'Sí');
    await _select(tester, 'specialty-filter-order', 'Fecha de alta');
    await _tap(tester, 'specialty-filter-search');
    expect(repository.queries, hasLength(3));

    await _tap(tester, 'specialty-filter-clear');

    expect(repository.queries, hasLength(4));
    expect(repository.queries.last.toQueryParameters(), isEmpty);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('specialty-filter-name')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .state<FormFieldState<bool>>(
            find.byKey(const Key('specialty-filter-referral')),
          )
          .value,
      isNull,
    );
    expect(
      tester
          .state<FormFieldState<SpecialtyOrder>>(
            find.byKey(const Key('specialty-filter-order')),
          )
          .value,
      SpecialtyOrder.name,
    );
  });

  testWidgets(
    'Sí y Fecha de alta envían exactamente los filtros seleccionados',
    (tester) async {
      final repository = _Repository();
      await _pump(tester, repository);
      await _select(tester, 'specialty-filter-referral', 'Sí');
      await _select(tester, 'specialty-filter-order', 'Fecha de alta');
      expect(repository.queries, hasLength(2));
      expect(repository.queries.last.toQueryParameters(), {
        'orden': 'fechaAlta',
      });

      await _tap(tester, 'specialty-filter-search');

      expect(repository.queries, hasLength(3));
      expect(repository.queries.last.toQueryParameters(), {
        'requierePase': true,
        'orden': 'fechaAlta',
      });
    },
  );

  testWidgets('un nombre de solo espacios no se envía', (tester) async {
    final repository = _Repository();
    await _pump(tester, repository);
    await _enterName(tester, '   ');

    await _tap(tester, 'specialty-filter-search');

    expect(repository.queries, hasLength(2));
    expect(repository.queries.last.toQueryParameters(), isEmpty);
  });

  testWidgets('sin coincidencias con filtros muestra el mensaje específico', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);
    repository.items = [];
    await _enterName(tester, 'inexistente');

    await _tap(tester, 'specialty-filter-search');

    expect(find.byKey(const Key('specialty-filter-empty')), findsOneWidget);
    expect(find.text('No hay especialidades que coincidan.'), findsOneWidget);
    expect(
      find.text('Todavía no hay especialidades registradas.'),
      findsNothing,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('sin filtros ni especialidades conserva el mensaje original', (
    tester,
  ) async {
    final repository = _Repository()..items = [];
    await _pump(tester, repository);

    expect(
      find.text('Todavía no hay especialidades registradas.'),
      findsOneWidget,
    );
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

    expect(
      find.text('El nombre no puede superar los 120 caracteres.'),
      findsOneWidget,
    );
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

    expect(
      find.text('Tu sesión venció. Iniciá sesión nuevamente.'),
      findsOneWidget,
    );
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

  testWidgets(
    'Reintentar repite los filtros aplicados y no los controles editados',
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
      expect(repository.queries, hasLength(3));
      expect(
        find.text('No se pudo completar la búsqueda de prueba.'),
        findsOneWidget,
      );

      await _enterName(tester, 'pedi');
      await _select(tester, 'specialty-filter-referral', 'No');
      expect(repository.queries, hasLength(3));
      repository.error = null;
      final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await _settle(tester);

      expect(repository.queries, hasLength(4));
      expect(repository.queries.last.toQueryParameters(), {
        'nombre': 'cardio',
        'requierePase': true,
        'orden': 'fechaAlta',
      });
      expect(find.text('Medicina General'), findsOneWidget);
      expect(find.text('Cardiología'), findsOneWidget);
      expect(
        find.text('No se pudo completar la búsqueda de prueba.'),
        findsNothing,
      );
    },
  );
}
