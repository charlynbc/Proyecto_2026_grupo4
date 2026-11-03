import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/especialidades/models/specialty_filters.dart';
import 'package:agenda_medica/features/especialidades/repositories/api_specialty_search_repository.dart';
import 'package:agenda_medica/features/especialidades/repositories/specialty_search_repository.dart';
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

(ApiSpecialtySearchRepository, _Adapter) _repository(int status, Object? body) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return (ApiSpecialtySearchRepository(dio), adapter);
}

Matcher get _genericError => isA<ApiException>().having(
  (error) => error.message,
  'mensaje genérico',
  kApiGenericMessage,
);

Matcher _failure(SpecialtySearchFailure failure) =>
    isA<SpecialtySearchException>().having(
      (error) => error.failure,
      'tipo de error',
      failure,
    );

void main() {
  group('ApiSpecialtySearchRepository.search', () {
    test('sin filtros pide GET /api/especialidades sin parámetros', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.search(const SpecialtyFilters());

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/especialidades');
      expect(adapter.last!.queryParameters, <String, dynamic>{});
    });

    test('envía exactamente nombre, requierePase y orden fechaAlta', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.search(
        const SpecialtyFilters(
          name: 'cardio',
          requiresReferral: true,
          order: SpecialtyOrder.createdAt,
        ),
      );

      expect(adapter.last!.queryParameters, {
        'nombre': 'cardio',
        'requierePase': true,
        'orden': 'fechaAlta',
      });
    });

    test('requiere pase No envía únicamente requierePase false', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.search(const SpecialtyFilters(requiresReferral: false));

      expect(adapter.last!.queryParameters, {'requierePase': false});
    });

    test('el orden por nombre elegido explícitamente no se envía', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.search(const SpecialtyFilters(order: SpecialtyOrder.name));

      expect(adapter.last!.queryParameters, <String, dynamic>{});
    });

    test('interpreta los dos elementos del contrato en el orden recibido',
        () async {
      final (repository, _) = _repository(200, {
        'items': [
          {'id': 1, 'nombre': 'Medicina General', 'requierePase': false},
          {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
        ],
      });

      final items = await repository.search(const SpecialtyFilters());

      expect(items, hasLength(2));
      expect(items[0].id, 1);
      expect(items[0].name, 'Medicina General');
      expect(items[0].requiresReferral, isFalse);
      expect(items[1].id, 3);
      expect(items[1].name, 'Cardiología');
      expect(items[1].requiresReferral, isTrue);
    });

    test('una respuesta sin items se convierte en error genérico', () async {
      final (repository, _) = _repository(200, <String, dynamic>{});

      await expectLater(
        repository.search(const SpecialtyFilters()),
        throwsA(_genericError),
      );
    });

    test('requierePase no booleano se convierte en error genérico', () async {
      final (repository, _) = _repository(200, {
        'items': [
          {'id': 3, 'nombre': 'Cardiología', 'requierePase': 'true'},
        ],
      });

      await expectLater(
        repository.search(const SpecialtyFilters()),
        throwsA(_genericError),
      );
    });

    test('un nombre de 121 caracteres produce validation sin realizar HTTP',
        () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});
      final filters = SpecialtyFilters(name: List.filled(121, 'a').join());

      await expectLater(
        repository.search(filters),
        throwsA(
          isA<SpecialtySearchException>()
              .having(
                (error) => error.failure,
                'tipo de error',
                SpecialtySearchFailure.validation,
              )
              .having(
                (error) => error.message,
                'mensaje',
                'El nombre no puede superar los 120 caracteres.',
              ),
        ),
      );
      expect(adapter.last, isNull);
    });

    test('400 VALIDACION es validation y conserva el mensaje del servidor',
        () async {
      const message = 'El nombre no puede superar los 120 caracteres.';
      final (repository, _) = _repository(400, {
        'code': 'VALIDACION',
        'message': message,
      });

      await expectLater(
        repository.search(const SpecialtyFilters()),
        throwsA(
          isA<SpecialtySearchException>()
              .having(
                (error) => error.failure,
                'tipo de error',
                SpecialtySearchFailure.validation,
              )
              .having((error) => error.message, 'mensaje', message),
        ),
      );
    });

    test('401 NO_AUTENTICADO es unauthenticated', () async {
      final (repository, _) = _repository(401, {
        'code': 'NO_AUTENTICADO',
        'message': 'Se requiere autenticación.',
      });

      await expectLater(
        repository.search(const SpecialtyFilters()),
        throwsA(_failure(SpecialtySearchFailure.unauthenticated)),
      );
    });

    test('403 ACCESO_DENEGADO es forbidden', () async {
      final (repository, _) = _repository(403, {
        'code': 'ACCESO_DENEGADO',
        'message': 'No tenés permiso para realizar esta consulta.',
      });

      await expectLater(
        repository.search(const SpecialtyFilters()),
        throwsA(_failure(SpecialtySearchFailure.forbidden)),
      );
    });

    test('500 con otro código es other', () async {
      final (repository, _) = _repository(500, {
        'code': 'ERROR_INTERNO',
        'message': 'No se pudo completar la consulta.',
      });

      await expectLater(
        repository.search(const SpecialtyFilters()),
        throwsA(_failure(SpecialtySearchFailure.other)),
      );
    });
  });
}
