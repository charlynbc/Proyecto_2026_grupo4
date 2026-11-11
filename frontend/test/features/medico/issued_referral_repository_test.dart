import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/medico/models/issued_referral.dart';
import 'package:agenda_medica/features/medico/models/issued_referral_query.dart';
import 'package:agenda_medica/features/medico/repositories/api_issued_referral_repository.dart';
import 'package:agenda_medica/features/medico/repositories/issued_referral_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

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

(ApiIssuedReferralRepository, _StubAdapter) _api(int status, Object? body) {
  final adapter = _StubAdapter(status, body);
  return (
    ApiIssuedReferralRepository(Dio()..httpClientAdapter = adapter),
    adapter,
  );
}

Map<String, Object?> _item({String status = 'DISPONIBLE'}) => {
  'id': 78,
  'paciente': {
    'id': 21,
    'ci': '45678911',
    'nombre': 'Lucía',
    'apellido': 'Fernández',
  },
  'especialidadDestino': {'id': 4, 'nombre': 'Nutrición', 'requierePase': true},
  'emitidoEn': '2026-10-20T09:41:00-03:00',
  'venceEl': '2027-01-18',
  'situacion': status,
};

Map<String, Object?> _error(String code) => {
  'code': code,
  'message': 'texto del servidor',
};

Matcher _genericError() => throwsA(
  isA<ApiException>().having((e) => e.message, 'message', kApiGenericMessage),
);

void main() {
  group('el pedido', () {
    test('GET /api/medico/pases con los parámetros por defecto', () async {
      final (repository, adapter) = _api(200, <Object>[]);

      await repository.list(const IssuedReferralQuery());

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/medico/pases');
      expect(adapter.last!.queryParameters, {
        'orden': 'vencimiento',
        'sentido': 'asc',
      });
    });

    test('con situación, emisión y descendente', () async {
      final (repository, adapter) = _api(200, <Object>[]);

      await repository.list(
        const IssuedReferralQuery(
          status: ReferralStatus.used,
          order: IssuedReferralOrder.issue,
          direction: IssuedReferralDirection.descending,
        ),
      );

      expect(adapter.last!.queryParameters, {
        'situacion': 'UTILIZADO',
        'orden': 'emision',
        'sentido': 'desc',
      });
    });
  });

  group('la respuesta', () {
    test('lee la lista del contrato', () async {
      final (repository, _) = _api(200, [_item()]);

      final list = await repository.list(const IssuedReferralQuery());

      expect(list.length, 1);
      expect(list.single.id, 78);
      expect(list.single.patient.fullName, 'Lucía Fernández');
      expect(list.single.destination.name, 'Nutrición');
      expect(list.single.issuedAt, DateTime.utc(2026, 10, 20, 12, 41));
      expect(list.single.expiresOn, DateTime.utc(2027, 1, 18));
      expect(list.single.status, ReferralStatus.available);
    });

    test('una lista vacía da vacío', () async {
      final (repository, _) = _api(200, <Object>[]);

      expect(await repository.list(const IssuedReferralQuery()), isEmpty);
    });

    test('un ítem con situación desconocida da el error genérico', () {
      final (repository, _) = _api(200, [_item(status: 'ANULADO')]);

      expect(repository.list(const IssuedReferralQuery()), _genericError());
    });

    test('un ítem sin venceEl da el error genérico', () {
      final item = _item()..remove('venceEl');
      final (repository, _) = _api(200, [item]);

      expect(repository.list(const IssuedReferralQuery()), _genericError());
    });

    test('una respuesta que no es una lista da el error genérico', () {
      final (repository, _) = _api(200, {'pases': <Object>[]});

      expect(repository.list(const IssuedReferralQuery()), _genericError());
    });
  });

  group('los errores', () {
    for (final code in ['VALIDACION', 'ORDEN_INVALIDO', 'SENTIDO_INVALIDO']) {
      test('400 $code da el error genérico', () {
        final (repository, _) = _api(400, _error(code));

        expect(repository.list(const IssuedReferralQuery()), _genericError());
      });
    }

    test('403 ACCESO_DENEGADO es forbidden con el mensaje propio', () {
      final (repository, _) = _api(403, _error('ACCESO_DENEGADO'));

      expect(
        repository.list(const IssuedReferralQuery()),
        throwsA(
          isA<IssuedReferralException>()
              .having(
                (e) => e.failure,
                'failure',
                IssuedReferralFailure.forbidden,
              )
              .having(
                (e) => e.message,
                'message',
                'Tu cuenta no tiene permiso para consultar pases.',
              ),
        ),
      );
    });

    test('otro código usa el mensaje del servidor', () {
      final (repository, _) = _api(409, _error('OTRO_CODIGO'));

      expect(
        repository.list(const IssuedReferralQuery()),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'texto del servidor')
              .having((e) => e is IssuedReferralException, 'propia', isFalse),
        ),
      );
    });
  });
}
