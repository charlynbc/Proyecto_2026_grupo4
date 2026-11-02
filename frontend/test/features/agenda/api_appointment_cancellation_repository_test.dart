import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/repositories/api_appointment_cancellation_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_cancellation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

final _genericError = isA<ApiException>().having(
  (e) => e.message,
  'message',
  kApiGenericMessage,
);

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

(ApiAppointmentCancellationRepository, _Adapter) _repo(
  int status,
  Object? body,
) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiAppointmentCancellationRepository(dio), adapter);
}

void main() {
  test('cancela la consulta 9001 y lee el resultado', () async {
    final (repo, adapter) = _repo(200, {
      'consultaId': 9001,
      'estado': 'CANCELADA_SOCIO',
      'canceladaEn': '2026-10-15T08:03:10-03:00',
      'paseDevuelto': true,
    });

    final result = await repo.cancel(9001);

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/consultas/9001/cancelar');
    expect(adapter.last!.data, isNull);
    expect(result.appointmentId, 9001);
    expect(result.status, 'CANCELADA_SOCIO');
    expect(result.cancelledAt, DateTime.utc(2026, 10, 15, 11, 3, 10));
    expect(result.referralReturned, isTrue);
  });

  group('respuesta mal formada', () {
    test('estado atendida es el error genérico', () async {
      final (repo, _) = _repo(200, {
        'consultaId': 9001,
        'estado': 'ATENDIDA',
        'canceladaEn': '2026-10-15T08:03:10-03:00',
        'paseDevuelto': true,
      });

      await expectLater(repo.cancel(9001), throwsA(_genericError));
    });

    test('falta canceladaEn es el error genérico', () async {
      final (repo, _) = _repo(200, {
        'consultaId': 9001,
        'estado': 'CANCELADA_SOCIO',
        'paseDevuelto': true,
      });

      await expectLater(repo.cancel(9001), throwsA(_genericError));
    });

    test('paseDevuelto no booleano es el error genérico', () async {
      final (repo, _) = _repo(200, {
        'consultaId': 9001,
        'estado': 'CANCELADA_SOCIO',
        'canceladaEn': '2026-10-15T08:03:10-03:00',
        'paseDevuelto': 'si',
      });

      await expectLater(repo.cancel(9001), throwsA(_genericError));
    });
  });

  for (final id in [0, -3]) {
    test('el id $id es notFound sin enviar petición', () async {
      final (repo, adapter) = _repo(200, {});

      await expectLater(
        repo.cancel(id),
        throwsA(
          isA<CancellationException>().having(
            (e) => e.failure,
            'failure',
            CancellationFailure.notFound,
          ),
        ),
      );
      expect(adapter.last, isNull);
    });
  }

  const cases = {
    (404, 'NO_ENCONTRADO'): CancellationFailure.notFound,
    (409, 'CONSULTA_NO_AGENDADA'): CancellationFailure.notScheduled,
    (409, 'CANCELACION_FUERA_DE_PLAZO'): CancellationFailure.outsideWindow,
    (409, 'LLEGADA_YA_REGISTRADA'): CancellationFailure.alreadyArrived,
    (400, 'VALIDACION'): CancellationFailure.validation,
    (401, 'NO_AUTENTICADO'): CancellationFailure.unauthenticated,
    (403, 'ACCESO_DENEGADO'): CancellationFailure.forbidden,
    (500, 'OTRO'): CancellationFailure.other,
  };
  cases.forEach((key, failure) {
    test('${key.$2} (${key.$1}) es $failure', () async {
      final (repo, _) = _repo(key.$1, {
        'code': key.$2,
        'message': 'mensaje del servidor',
      });

      await expectLater(
        repo.cancel(9001),
        throwsA(
          isA<CancellationException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.message, 'message', 'mensaje del servidor'),
        ),
      );
    });
  });
}
