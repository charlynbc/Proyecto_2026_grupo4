import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_import_controller.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_import_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_provider.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_import_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/specialty_import_csv.dart';

class _CountingCatalog extends FakeSpecialtyRepository {
  _CountingCatalog(super.db) : super(latency: Duration.zero);

  int listCalls = 0;

  @override
  Future<List<Specialty>> list() {
    listCalls++;
    return super.list();
  }
}

class _CountingSearch extends FakeSpecialtySearchRepository {
  _CountingSearch(super.db) : super(latency: Duration.zero);

  int searchCalls = 0;

  @override
  Future<List<Specialty>> search(SpecialtyFilters filters) {
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
        specialtyRepositoryProvider.overrideWith((ref) async => catalog),
        specialtySearchRepositoryProvider.overrideWith((ref) async => search),
        specialtyImportRepositoryProvider.overrideWith(
          (ref) async =>
              FakeSpecialtyImportRepository(db, latency: Duration.zero),
        ),
      ],
    );
    container.listen(specialtiesProvider, (_, _) {});
    container.listen(specialtySearchProvider, (_, _) {});
    controller = container.read(specialtyImportControllerProvider.notifier);
    container.listen(specialtyImportControllerProvider, (_, _) {});
  }

  late final FakeAdminDatabase db;
  late final _CountingCatalog catalog;
  late final _CountingSearch search;
  late final ProviderContainer container;
  late final SpecialtyImportController controller;

  /// Espera a que el catálogo y el listado terminen de cargar.
  Future<void> settle() async {
    await container.read(specialtiesProvider.future);
    await container.read(specialtySearchProvider.future);
  }

  SpecialtyImportState get state =>
      container.read(specialtyImportControllerProvider);
}

void main() {
  test(
    'los pasos: sin archivo, con archivo, previsualizado y terminado',
    () async {
      final env = _Env();
      addTearDown(env.container.dispose);
      expect(env.state.stage, SpecialtyImportStage.noFile);

      env.controller.setFile(specialtyImportFile());
      expect(env.state.stage, SpecialtyImportStage.hasFile);
      expect(env.state.file!.name, 'especialidades-prueba.csv');

      await env.controller.preview();
      expect(env.state.stage, SpecialtyImportStage.previewed);
      expect(env.state.preview!.total, 7);

      await env.controller.confirm();
      expect(env.state.stage, SpecialtyImportStage.done);
      expect(env.state.result!.imported, 3);
      expect(env.state.preview, isNull);
    },
  );

  test('al importar al menos una invalida el catálogo y el listado', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.settle();
    expect(env.catalog.listCalls, 1);
    expect(env.search.searchCalls, 1);
    env.controller.setFile(specialtyImportFile());
    await env.controller.preview();

    await env.controller.confirm();
    await env.settle();

    expect(env.catalog.listCalls, 2);
    expect(env.search.searchCalls, 2);
    expect((await env.container.read(specialtiesProvider.future)).length, 6);
  });

  test('previsualizar no invalida nada', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.settle();
    env.controller.setFile(specialtyImportFile());

    await env.controller.preview();
    await env.settle();

    expect(env.catalog.listCalls, 1);
    expect(env.search.searchCalls, 1);
  });

  test('si no se importó ninguna no invalida nada', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    await env.settle();
    env.controller.setFile(
      specialtyCsvFile('$kSpecialtyImportHeader\nNeurología,si\n'),
    );
    await env.controller.preview();
    // Otra persona da de alta la misma especialidad entre los dos pasos.
    await FakeSpecialtyRepository(
      env.db,
      latency: Duration.zero,
    ).create(name: 'Neurología', requiresReferral: true);

    await env.controller.confirm();
    await env.settle();

    expect(env.state.stage, SpecialtyImportStage.done);
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
      env.controller.setFile(specialtyCsvFile('nombre,otra\nA,si\n'));

      await env.controller.preview();

      expect(env.state.stage, SpecialtyImportStage.hasFile);
      expect(
        env.state.errorMessage,
        'El CSV debe tener exactamente las columnas: nombre,requiere_pase',
      );
    },
  );

  test('cambiar el archivo reinicia todo', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    env.controller.setFile(specialtyImportFile());
    await env.controller.preview();
    expect(env.state.preview, isNotNull);

    env.controller.setFile(specialtyCsvFile('$kSpecialtyImportHeader\n'));

    expect(env.state.stage, SpecialtyImportStage.hasFile);
    expect(env.state.preview, isNull);
    expect(env.state.result, isNull);
    expect(env.state.errorMessage, isNull);
  });

  test('confirmar sin haber previsualizado no hace nada', () async {
    final env = _Env();
    addTearDown(env.container.dispose);
    env.controller.setFile(specialtyImportFile());

    await env.controller.confirm();

    expect(env.state.stage, SpecialtyImportStage.hasFile);
    expect(env.db.specialties.length, 3);
  });
}
