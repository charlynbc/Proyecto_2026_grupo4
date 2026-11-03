import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_search_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/api_specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'items': <Object>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('selecciona Fake sin inicializar Dio y utiliza la base existente',
      () async {
    var dioCalls = 0;
    final db = FakeAdminDatabase();
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        fakeAdminDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWith((ref) async {
          dioCalls++;
          throw StateError('El modo Fake no debe inicializar Dio.');
        }),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      specialtySearchRepositoryProvider.future,
    );
    // Una base vacía permite distinguir la instancia suministrada de otra nueva.
    db.specialties.clear();
    final items = await repository.search(const SpecialtyFilters());

    expect(repository, isA<FakeSpecialtySearchRepository>());
    expect(items, isEmpty);
    expect(dioCalls, 0);
  });

  test('selecciona API sin realizar consultas al construir el repositorio',
      () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    var dioCalls = 0;
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(false),
        dioProvider.overrideWith((ref) async {
          dioCalls++;
          return dio;
        }),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      specialtySearchRepositoryProvider.future,
    );

    expect(repository, isA<ApiSpecialtySearchRepository>());
    expect(dioCalls, 1);
    expect(adapter.requests, isEmpty);
  });

  test('la API reutiliza el Dio compartido y sus interceptores', () async {
    final adapter = _Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    var interceptorCalls = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      interceptorCalls++;
      options.headers['X-Prueba-Compartida'] = 'rf36';
      handler.next(options);
    }));
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(false),
        dioProvider.overrideWith((ref) async => dio),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      specialtySearchRepositoryProvider.future,
    );
    final items = await repository.search(const SpecialtyFilters());

    expect(items, isEmpty);
    expect(interceptorCalls, 1);
    expect(adapter.requests.single.path, '/api/especialidades');
    expect(adapter.requests.single.headers['X-Prueba-Compartida'], 'rf36');
  });
}
