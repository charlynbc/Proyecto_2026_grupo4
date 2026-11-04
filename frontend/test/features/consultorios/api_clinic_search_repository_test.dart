import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/consultorios/models/clinic_filters.dart';
import 'package:agenda_medica/features/consultorios/repositories/api_clinic_search_repository.dart';
import 'package:agenda_medica/features/consultorios/repositories/clinic_search_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registra el pedido y responde con JSON en memoria, sin conexiones HTTP.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Object? body;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiClinicSearchRepository, _Adapter) _repository(int status, Object? body) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (ApiClinicSearchRepository(dio), adapter);
}

Matcher get _genericError => isA<ApiException>().having(
  (error) => error.message,
  'mensaje genérico',
  kApiGenericMessage,
);

Matcher _failure(ClinicSearchFailure failure) => isA<ClinicSearchException>()
    .having((error) => error.failure, 'tipo de error', failure);

void main() {
  group('ApiClinicSearchRepository.search', () {
    test('sin filtros pide GET /api/consultorios sin parámetros', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.search(const ClinicFilters());

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/consultorios');
      expect(adapter.last!.queryParameters, <String, dynamic>{});
    });

    test('envía nombre, ubicación y orden ubicacion', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.search(
        const ClinicFilters(
          name: '5',
          location: 'norte',
          order: ClinicOrder.location,
        ),
      );

      expect(adapter.last!.queryParameters, {
        'nombre': '5',
        'ubicacion': 'norte',
        'orden': 'ubicacion',
      });
    });

    test('el orden por nombre no se envía', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.search(const ClinicFilters(order: ClinicOrder.name));

      expect(adapter.last!.queryParameters, <String, dynamic>{});
    });

    test('lee los dos consultorios del contrato en ese orden', () async {
      final (repository, _) = _repository(200, {
        'items': [
          {
            'id': 5,
            'nombre': 'Consultorio 5',
            'ubicacion': 'Piso 2, ala norte',
          },
          {'id': 6, 'nombre': 'Consultorio 6', 'ubicacion': 'Piso 2, ala sur'},
        ],
      });

      final items = await repository.search(const ClinicFilters());

      expect(items, hasLength(2));
      expect(items[0].id, 5);
      expect(items[0].name, 'Consultorio 5');
      expect(items[0].location, 'Piso 2, ala norte');
      expect(items[1].id, 6);
      expect(items[1].name, 'Consultorio 6');
      expect(items[1].location, 'Piso 2, ala sur');
    });

    test('una respuesta sin items es el error genérico', () async {
      final (repository, _) = _repository(200, <String, dynamic>{});

      await expectLater(
        repository.search(const ClinicFilters()),
        throwsA(_genericError),
      );
    });

    test('un id que no es entero es el error genérico', () async {
      final (repository, _) = _repository(200, {
        'items': [
          {'id': '5', 'nombre': 'Consultorio 5', 'ubicacion': 'Piso 2'},
        ],
      });

      await expectLater(
        repository.search(const ClinicFilters()),
        throwsA(_genericError),
      );
    });

    test(
      '400 VALIDACION es validation y conserva el mensaje del servidor',
      () async {
        const message = 'La ubicación no puede superar los 200 caracteres.';
        final (repository, _) = _repository(400, {
          'code': 'VALIDACION',
          'message': message,
        });

        await expectLater(
          repository.search(const ClinicFilters()),
          throwsA(
            isA<ClinicSearchException>()
                .having(
                  (error) => error.failure,
                  'tipo de error',
                  ClinicSearchFailure.validation,
                )
                .having((error) => error.message, 'mensaje', message),
          ),
        );
      },
    );

    test('401 NO_AUTENTICADO es unauthenticated', () async {
      final (repository, _) = _repository(401, {
        'code': 'NO_AUTENTICADO',
        'message': 'Se requiere autenticación.',
      });

      await expectLater(
        repository.search(const ClinicFilters()),
        throwsA(_failure(ClinicSearchFailure.unauthenticated)),
      );
    });

    test('403 ACCESO_DENEGADO es forbidden', () async {
      final (repository, _) = _repository(403, {
        'code': 'ACCESO_DENEGADO',
        'message': 'No tenés permiso para realizar esta consulta.',
      });

      await expectLater(
        repository.search(const ClinicFilters()),
        throwsA(_failure(ClinicSearchFailure.forbidden)),
      );
    });

    test('500 con otro código es other', () async {
      final (repository, _) = _repository(500, {
        'code': 'ERROR_INTERNO',
        'message': 'No se pudo completar la consulta.',
      });

      await expectLater(
        repository.search(const ClinicFilters()),
        throwsA(_failure(ClinicSearchFailure.other)),
      );
    });
  });
}
