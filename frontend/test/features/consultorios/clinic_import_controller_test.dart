import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_filters_controller.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_import_controller.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_import_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinic_search_repository_provider.dart';
import 'package:agenda_medica/features/consultorios/providers/clinics_provider.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_import_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/fake_clinic_search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/clinic_import_csv.dart';

class _CountingCatalog extends FakeClinicRepository {
  _CountingCatalog(super.db) : super(latency: Duration.zero);

  int listCalls = 0;

  @override
  Future<List<Clinic>> list() {
    listCalls++;
    return super.list();
  }
}

class _CountingSearch extends FakeClinicSearchRepository {
  _CountingSearch(super.db) : super(latency: Duration.zero);

  int searchCalls = 0;

  @override
  Future<List<Clinic>> search(ClinicFilters filters) {
    searchCalls++;
    return super.search(filters);
  }
}

class _Env {
  _Env() {
    db = FakeAdminDatabase();
    catalog = _CountingCatalog(db);
    search = _CountingSearch(db);
    container = ProviderContainer(
      overrides: [
        clinicRepositoryProvider.overrideWith((ref) async => catalog),
        clinicSearchRepositoryProvider.overrideWith((ref) async => search),
        clinicImportRepositoryProvider.overrideWith(
          (ref) async => FakeClinicImportRepository(db, latency: Duration.zero),
        ),
      ],
    );
    container.listen(clinicsProvider, (_, _) {});
    container.listen(clinicSearchProvider, (_, _) {});
    container.listen(clinicFiltersControllerProvider, (_, _) {});
    controller = container.read(clinicImportControllerProvider.notifier);
    container.listen(clinicImportControllerProvider, (_, _) {});
  }

  late final FakeAdminDatabase db;
  late final _CountingCatalog catalog;
  late final _CountingSearch search;
  late final ProviderContainer container;
  late final ClinicImportController controller;

  /// Espera a que el catálogo y el listado terminen de cargar.
  Future<void> settle() async {
    await container.read(clinicsProvider.future);
    await container.read(clinicSearchProvider.future);
  }

  ClinicImportState get state => container.read(clinicImportControllerProvider);

  ClinicFilters get filters => container.read(clinicFiltersControllerProvider);
}

void main() {
  test(
    'los pasos: sin archivo, con archivo, previsualizado y terminado',
    () async {
      final env = _Env();
      addTearDown(env.container.dispose);
      expect(env.state.stage, ClinicImportStage.noFile);

      env.controller.setFile(clinicImportFile());
      expect(env.state.stage, ClinicImportStage.hasFile);
      expect(env.state.file!.name, 'consultorios-prueba.csv');

      await env.controller.preview();
      expect(env.state.stage, ClinicImportStage.previewed);
      expect(env.state.preview!.total, 7);

      await env.controller.confirm();
      expect(env.state.stage, ClinicImportStage.done);
      expect(env.state.result!.imported, 2);
      expect(env.state.preview, isNull);
    },
  );

  test('al importar al menos uno invalida el catálogo y el listado', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.settle();
    expect(env.catalog.listCalls, 1);
    expect(env.search.searchCalls, 1);
    env.controller.setFile(clinicImportFile());
    await env.controller.preview();

    await env.controller.confirm();
    await env.settle();

    expect(env.catalog.listCalls, 2);
    expect(env.search.searchCalls, 2);
    expect((await env.container.read(clinicsProvider.future)).length, 5);
  });

  test('no toca los filtros ni el sentido del listado', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    env.container
        .read(clinicFiltersControllerProvider.notifier)
        .apply(name: '2', location: 'Piso', order: ClinicOrder.location);
    env.container
        .read(clinicFiltersControllerProvider.notifier)
        .toggleDirection();
    await env.settle();
    env.controller.setFile(clinicImportFile());
    await env.controller.preview();

    await env.controller.confirm();
    await env.settle();

    expect(env.filters.name, '2');
    expect(env.filters.location, 'Piso');
    expect(env.filters.order, ClinicOrder.location);
    expect(env.filters.ascending, isFalse);
  });

  test('previsualizar no invalida nada', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.settle();
    env.controller.setFile(clinicImportFile());

    await env.controller.preview();
    await env.settle();

    expect(env.catalog.listCalls, 1);
    expect(env.search.searchCalls, 1);
  });

  test('si no se importó ninguno no invalida nada', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.settle();
    env.controller.setFile(
      clinicCsvFile('$kClinicImportHeader\nConsultorio 20,Piso 3\n'),
    );
    await env.controller.preview();
    // Otra persona da de alta el mismo consultorio entre los dos pasos.
    await FakeClinicRepository(
      env.db,
      latency: Duration.zero,
    ).create(name: 'Consultorio 20', location: 'Piso 8');

    await env.controller.confirm();
    await env.settle();

    expect(env.state.stage, ClinicImportStage.done);
    expect(env.state.result!.imported, 0);
    expect(env.state.result!.rejected, 1);
    expect(env.catalog.listCalls, 1);
    expect(env.search.searchCalls, 1);
  });

  test(
    'un error al previsualizar vuelve a "con archivo" con el mensaje',
    () async {
      final env = _Env();
      addTearDown(env.container.dispose);
      env.controller.setFile(clinicCsvFile('nombre,otra\nA,B\n'));

      await env.controller.preview();

      expect(env.state.stage, ClinicImportStage.hasFile);
      expect(
        env.state.errorMessage,
        'El CSV debe tener exactamente las columnas: nombre, ubicacion',
      );
    },
  );

  test('cambiar el archivo reinicia todo', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    env.controller.setFile(clinicImportFile());
    await env.controller.preview();
    expect(env.state.preview, isNotNull);

    env.controller.setFile(clinicCsvFile('$kClinicImportHeader\n'));

    expect(env.state.stage, ClinicImportStage.hasFile);
    expect(env.state.preview, isNull);
    expect(env.state.result, isNull);
    expect(env.state.errorMessage, isNull);
  });

  test('confirmar sin haber previsualizado no hace nada', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    env.controller.setFile(clinicImportFile());

    await env.controller.confirm();

    expect(env.state.stage, ClinicImportStage.hasFile);
    expect(env.db.clinics.length, 3);
  });
}
