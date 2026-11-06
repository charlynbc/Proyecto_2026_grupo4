import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_filters_controller.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingRepository implements SpecialtySearchRepository {
  final List<SpecialtyFilters> queries = [];
  Object? error;

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) async {
    queries.add(filters);
    if (error != null) throw error!;
    return const [
      Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
    ];
  }
}

class _RecordingFakeRepository implements SpecialtySearchRepository {
  _RecordingFakeRepository(FakeAdminDatabase db)
    : _delegate = FakeSpecialtySearchRepository(db, latency: Duration.zero);

  final FakeSpecialtySearchRepository _delegate;
  final List<SpecialtyFilters> queries = [];
  final List<List<Specialty>> responses = [];

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) async {
    queries.add(filters);
    final items = await _delegate.search(filters);
    responses.add(items);
    return items;
  }
}

ProviderContainer _mount(_RecordingRepository repository) {
  final container = ProviderContainer(
    overrides: [
      specialtySearchRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  container.listen(specialtySearchProvider, (_, _) {}, onError: (_, _) {});
  return container;
}

void main() {
  group('orden inmediato y sentido local', () {
    late FakeAdminDatabase db;
    late _RecordingFakeRepository repository;
    late ProviderContainer container;

    setUp(() {
      db = FakeAdminDatabase();
      db.specialties.add(
        Specialty(
          id: db.newSpecialtyId(),
          name: 'Neurología',
          requiresReferral: false,
        ),
      );
      repository = _RecordingFakeRepository(db);
      container = ProviderContainer(
        overrides: [
          specialtySearchRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(
        specialtySearchResultsProvider,
        (_, _) {},
        onError: (_, _) {},
      );
    });

    Future<void> loadResults() async {
      await container.pump();
      await container.read(specialtySearchProvider.future);
      await container.pump();
      expect(container.read(specialtySearchResultsProvider).hasError, isFalse);
      expect(container.read(specialtySearchResultsProvider).isLoading, isFalse);
    }

    Iterable<String> displayedNames() => container
        .read(specialtySearchResultsProvider)
        .requireValue
        .map((item) => item.name);

    test(
      'sortBy consulta inmediatamente conservando nombre y pase aplicados',
      () async {
        await loadResults();
        final controller = container.read(
          specialtyFiltersControllerProvider.notifier,
        );
        controller.apply(name: 'logía', requiresReferral: true);
        await loadResults();
        expect(repository.queries, hasLength(2));
        expect(displayedNames(), ['Cardiología', 'Dermatología']);

        controller.sortBy(SpecialtyOrder.createdAt, ascending: true);
        final applied = container.read(specialtyFiltersControllerProvider);
        expect(applied.name, 'logía');
        expect(applied.requiresReferral, isTrue);
        expect(applied.order, SpecialtyOrder.createdAt);
        expect(applied.ascending, isTrue);
        await loadResults();

        expect(repository.queries, hasLength(3));
        expect(repository.queries.last.toQueryParameters(), {
          'nombre': 'logía',
          'requierePase': true,
          'orden': 'fechaAlta',
        });
        expect(displayedNames(), ['Cardiología', 'Dermatología']);
      },
    );

    test(
      'Nombre invierte y recupera el listado sin consultas adicionales',
      () async {
        await loadResults();
        expect(displayedNames(), [
          'Cardiología',
          'Dermatología',
          'Medicina General',
          'Neurología',
        ]);
        expect(repository.queries, hasLength(1));
        final controller = container.read(
          specialtyFiltersControllerProvider.notifier,
        );

        controller.sortBy(SpecialtyOrder.name, ascending: false);
        await loadResults();

        expect(displayedNames(), [
          'Neurología',
          'Medicina General',
          'Dermatología',
          'Cardiología',
        ]);
        expect(repository.queries, hasLength(1));

        controller.sortBy(SpecialtyOrder.name, ascending: true);
        await loadResults();

        expect(displayedNames(), [
          'Cardiología',
          'Dermatología',
          'Medicina General',
          'Neurología',
        ]);
        expect(repository.queries, hasLength(1));
      },
    );

    test(
      'Fecha de alta invierte y recupera el listado sin consultas adicionales',
      () async {
        await loadResults();
        final controller = container.read(
          specialtyFiltersControllerProvider.notifier,
        );
        controller.sortBy(SpecialtyOrder.createdAt, ascending: true);
        await loadResults();
        expect(displayedNames(), [
          'Medicina General',
          'Cardiología',
          'Dermatología',
          'Neurología',
        ]);
        expect(repository.queries, hasLength(2));

        controller.sortBy(SpecialtyOrder.createdAt, ascending: false);
        await loadResults();

        expect(displayedNames(), [
          'Neurología',
          'Dermatología',
          'Cardiología',
          'Medicina General',
        ]);
        expect(repository.queries, hasLength(2));

        controller.sortBy(SpecialtyOrder.createdAt, ascending: true);
        await loadResults();

        expect(displayedNames(), [
          'Medicina General',
          'Cardiología',
          'Dermatología',
          'Neurología',
        ]);
        expect(repository.queries, hasLength(2));
      },
    );

    test(
      'cambiar el criterio conserva el sentido descendente aplicado',
      () async {
        await loadResults();
        final controller = container.read(
          specialtyFiltersControllerProvider.notifier,
        );
        controller.sortBy(SpecialtyOrder.name, ascending: false);
        await loadResults();
        expect(repository.queries, hasLength(1));

        controller.sortBy(
          SpecialtyOrder.createdAt,
          ascending: container
              .read(specialtyFiltersControllerProvider)
              .ascending,
        );
        expect(
          container.read(specialtyFiltersControllerProvider).ascending,
          isFalse,
        );
        await loadResults();

        expect(displayedNames(), [
          'Neurología',
          'Dermatología',
          'Cardiología',
          'Medicina General',
        ]);
        expect(repository.queries, hasLength(2));

        controller.sortBy(
          SpecialtyOrder.name,
          ascending: container
              .read(specialtyFiltersControllerProvider)
              .ascending,
        );
        await loadResults();

        expect(
          container.read(specialtyFiltersControllerProvider).ascending,
          isFalse,
        );
        expect(displayedNames(), [
          'Neurología',
          'Medicina General',
          'Dermatología',
          'Cardiología',
        ]);
        expect(repository.queries, hasLength(3));
      },
    );

    test(
      'invertir no modifica la respuesta original ni la colección Fake',
      () async {
        await loadResults();
        final original = repository.responses.single;
        final controller = container.read(
          specialtyFiltersControllerProvider.notifier,
        );

        controller.sortBy(SpecialtyOrder.name, ascending: false);
        await loadResults();

        expect(displayedNames(), [
          'Neurología',
          'Medicina General',
          'Dermatología',
          'Cardiología',
        ]);
        expect(original.map((item) => item.name), [
          'Cardiología',
          'Dermatología',
          'Medicina General',
          'Neurología',
        ]);
        expect(
          await container.read(specialtySearchProvider.future),
          same(original),
        );
        expect(db.specialties.map((item) => item.name), [
          'Medicina General',
          'Cardiología',
          'Dermatología',
          'Neurología',
        ]);
        expect(repository.queries, hasLength(1));
      },
    );

    test(
      'la consulta depende de nombre, pase y criterio pero no del sentido',
      () async {
        await loadResults();
        final controller = container.read(
          specialtyFiltersControllerProvider.notifier,
        );
        expect(repository.queries, hasLength(1));

        controller.apply(name: 'logía');
        await loadResults();
        expect(repository.queries, hasLength(2));
        expect(repository.queries.last.toQueryParameters(), {
          'nombre': 'logía',
        });
        expect(displayedNames(), ['Cardiología', 'Dermatología', 'Neurología']);

        controller.apply(name: 'logía', requiresReferral: false);
        await loadResults();
        expect(repository.queries, hasLength(3));
        expect(repository.queries.last.toQueryParameters(), {
          'nombre': 'logía',
          'requierePase': false,
        });
        expect(displayedNames(), ['Neurología']);

        controller.sortBy(SpecialtyOrder.createdAt, ascending: true);
        await loadResults();
        expect(repository.queries, hasLength(4));
        expect(repository.queries.last.toQueryParameters(), {
          'nombre': 'logía',
          'requierePase': false,
          'orden': 'fechaAlta',
        });

        controller.sortBy(SpecialtyOrder.createdAt, ascending: false);
        await loadResults();
        expect(displayedNames(), ['Neurología']);
        expect(repository.queries, hasLength(4));
      },
    );
  });

  test('la búsqueda inicial utiliza filtros predeterminados', () async {
    final repository = _RecordingRepository();
    final container = _mount(repository);
    addTearDown(container.dispose);

    final items = await container.read(specialtySearchProvider.future);

    expect(repository.queries, hasLength(1));
    final filters = repository.queries.single;
    expect(filters.name, isNull);
    expect(filters.requiresReferral, isNull);
    expect(filters.order, SpecialtyOrder.name);
    expect(filters.toQueryParameters(), isEmpty);
    expect(items.map((item) => item.id), [3]);
  });

  test(
    'editar valores locales no aplica filtros ni ejecuta otra búsqueda',
    () async {
      final repository = _RecordingRepository();
      final container = _mount(repository);
      addTearDown(container.dispose);
      await container.read(specialtySearchProvider.future);

      // Representa los controles todavía no enviados con Buscar.
      var draft = const SpecialtyFilters();
      draft = const SpecialtyFilters(
        name: 'cardio',
        requiresReferral: true,
        order: SpecialtyOrder.createdAt,
      );
      await container.pump();

      expect(draft.name, 'cardio');
      expect(repository.queries, hasLength(1));
      expect(
        container.read(specialtyFiltersControllerProvider).toQueryParameters(),
        isEmpty,
      );
    },
  );

  test(
    'aplicar filtros ejecuta la búsqueda con los valores seleccionados',
    () async {
      final repository = _RecordingRepository();
      final container = _mount(repository);
      addTearDown(container.dispose);
      await container.read(specialtySearchProvider.future);

      container
          .read(specialtyFiltersControllerProvider.notifier)
          .apply(
            name: 'cardio',
            requiresReferral: true,
            order: SpecialtyOrder.createdAt,
          );
      await container.pump();
      await container.read(specialtySearchProvider.future);

      expect(repository.queries, hasLength(2));
      final applied = container.read(specialtyFiltersControllerProvider);
      expect(applied.name, 'cardio');
      expect(applied.requiresReferral, isTrue);
      expect(applied.order, SpecialtyOrder.createdAt);
      expect(repository.queries.last.toQueryParameters(), {
        'nombre': 'cardio',
        'requierePase': true,
        'orden': 'fechaAlta',
      });
    },
  );

  test('limpiar restaura los valores y consulta sin parámetros', () async {
    final repository = _RecordingRepository();
    final container = _mount(repository);
    addTearDown(container.dispose);
    await container.read(specialtySearchProvider.future);
    final controller = container.read(
      specialtyFiltersControllerProvider.notifier,
    );
    controller.apply(
      name: 'cardio',
      requiresReferral: false,
      order: SpecialtyOrder.createdAt,
    );
    await container.pump();
    await container.read(specialtySearchProvider.future);

    controller.clear();
    await container.pump();
    await container.read(specialtySearchProvider.future);

    final applied = container.read(specialtyFiltersControllerProvider);
    expect(applied.name, isNull);
    expect(applied.requiresReferral, isNull);
    expect(applied.order, SpecialtyOrder.name);
    expect(repository.queries, hasLength(3));
    expect(repository.queries.last.toQueryParameters(), isEmpty);
  });

  test(
    'reintentar conserva la búsqueda aplicada aunque cambien los controles',
    () async {
      final repository = _RecordingRepository();
      final container = _mount(repository);
      addTearDown(container.dispose);
      await container.read(specialtySearchProvider.future);
      const failure = SpecialtySearchException(
        SpecialtySearchFailure.validation,
        'No se pudo completar la búsqueda de prueba.',
      );
      repository.error = failure;
      container
          .read(specialtyFiltersControllerProvider.notifier)
          .apply(
            name: 'cardio',
            requiresReferral: true,
            order: SpecialtyOrder.createdAt,
          );
      await expectLater(
        container.read(specialtySearchProvider.future),
        throwsA(same(failure)),
      );

      // Edición local posterior al error, sin pulsar Buscar.
      const draft = SpecialtyFilters(name: 'pedi', requiresReferral: false);
      repository.error = null;
      container.invalidate(specialtySearchProvider);
      await container.pump();
      final items = await container.read(specialtySearchProvider.future);

      expect(draft.name, 'pedi');
      expect(repository.queries, hasLength(3));
      expect(repository.queries.last.toQueryParameters(), {
        'nombre': 'cardio',
        'requierePase': true,
        'orden': 'fechaAlta',
      });
      expect(items.single.name, 'Cardiología');
      expect(container.read(specialtySearchProvider).hasError, isFalse);
    },
  );

  testWidgets('una búsqueda fallida no provoca reintentos automáticos', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    const failure = SpecialtySearchException(
      SpecialtySearchFailure.other,
      'No se pudo completar la consulta de prueba.',
    );
    repository.error = failure;
    final container = _mount(repository);
    try {
      await expectLater(
        container.read(specialtySearchProvider.future),
        throwsA(same(failure)),
      );
      await tester.pump(const Duration(seconds: 2));

      final state = container.read(specialtySearchProvider);
      expect(state.hasError, isTrue);
      expect(state.error, same(failure));
      expect(state.hasValue, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.retrying, isFalse);
      expect(repository.queries, hasLength(1));
    } finally {
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    }
  });
}
