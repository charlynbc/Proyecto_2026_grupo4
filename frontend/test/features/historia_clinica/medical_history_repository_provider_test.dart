import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/config/app_config.dart';
import 'package:agenda_medica/core/network/dio_client.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/providers/medical_history_repository_provider.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/api_medical_history_repository.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responde en memoria y registra los pedidos, sin abrir conexiones.
class _StubAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      jsonEncode(<Object>[]),
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
  test('con fakes activos selecciona el fake sin evaluar Dio', () async {
    var dioEvaluations = 0;
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(true),
        dioProvider.overrideWith((ref) async {
          dioEvaluations++;
          throw StateError('Dio no debe evaluarse en modo falso.');
        }),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      medicalHistoryRepositoryProvider.future,
    );

    expect(repository, isA<FakeMedicalHistoryRepository>());
    expect(dioEvaluations, 0);
  });

  test('con fakes desactivados selecciona el repositorio API', () async {
    final adapter = _StubAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));

    var dioEvaluations = 0;
    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(false),
        dioProvider.overrideWith((ref) async {
          dioEvaluations++;
          return dio;
        }),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      medicalHistoryRepositoryProvider.future,
    );

    expect(repository, isA<ApiMedicalHistoryRepository>());
    expect(dioEvaluations, 1);
    expect(adapter.requests, isEmpty);
  });

  test('el repositorio API utiliza el Dio compartido y sus interceptores',
      () async {
    final adapter = _StubAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    var interceptorCalls = 0;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          interceptorCalls++;
          options.headers['X-Prueba-Compartida'] = 'rf12';
          handler.next(options);
        },
      ),
    );
    addTearDown(() => dio.close(force: true));

    final container = ProviderContainer(
      overrides: [
        useFakesProvider.overrideWithValue(false),
        dioProvider.overrideWith((ref) async => dio),
      ],
    );
    addTearDown(container.dispose);

    final repository = await container.read(
      medicalHistoryRepositoryProvider.future,
    );
    final entries = await repository.list(
      const MedicalHistoryQuery(),
    );

    expect(entries, isEmpty);
    expect(interceptorCalls, 1);

    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/api/historia-clinica');
    expect(request.headers['X-Prueba-Compartida'], 'rf12');
  });
}
