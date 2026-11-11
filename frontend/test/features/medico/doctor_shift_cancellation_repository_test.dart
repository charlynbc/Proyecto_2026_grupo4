import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/medico/repositories/api_doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_cancellation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class Stub implements HttpClientAdapter {
  Stub(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? request;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

const body = {
  'turnoId': 301,
  'fecha': '2026-10-30',
  'estado': 'SUSPENDIDO',
  'consultasCanceladas': 2,
  'pasesDevueltos': 1,
};
void main() {
  test('POST y respuesta del contrato', () async {
    final stub = Stub(200, body);
    final result = await ApiDoctorCancellationRepository(
      Dio()..httpClientAdapter = stub,
    ).cancelShift(301, ' Guardia ');
    expect(stub.request!.method, 'POST');
    expect(stub.request!.path, '/api/medico/turnos/301/cancelar');
    expect(stub.request!.data, {'motivo': 'Guardia'});
    expect(result.shiftId, 301);
    expect(result.date, DateTime.utc(2026, 10, 30));
    expect(result.status, 'SUSPENDIDO');
    expect(result.cancelledCount, 2);
    expect(result.returnedReferralsCount, 1);
  });
  test('acepta cero consultas', () async {
    final stub = Stub(200, {...body, 'consultasCanceladas': 0});
    expect(
      (await ApiDoctorCancellationRepository(
        Dio()..httpClientAdapter = stub,
      ).cancelShift(301, 'x')).cancelledCount,
      0,
    );
  });
  test('valida sin llamar', () async {
    for (final (id, reason) in [
      (0, 'x'),
      (-3, 'x'),
      (301, ' '),
      (301, 'a' * 1001),
    ]) {
      final stub = Stub(200, body);
      await expectLater(
        ApiDoctorCancellationRepository(Dio()..httpClientAdapter = stub)
            .cancelShift(id, reason),
        throwsA(
          isA<DoctorCancellationException>().having(
            (e) => e.failure,
            'failure',
            DoctorCancellationFailure.validation,
          ),
        ),
      );
      expect(stub.request, isNull);
    }
  });
  test('rechaza datos inválidos', () async {
    for (final value in [
      {...body, 'estado': 'ACTIVO'},
      {...body}..remove('fecha'),
      {...body, 'consultasCanceladas': -1},
      {...body, 'turnoId': '301'},
      {...body, 'consultasCanceladas': '2'},
      {...body, 'pasesDevueltos': '1'},
    ]) {
      final stub = Stub(200, value);
      await expectLater(
        ApiDoctorCancellationRepository(Dio()..httpClientAdapter = stub)
            .cancelShift(301, 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            kApiGenericMessage,
          ),
        ),
      );
    }
  });
  test(
    'un código desconocido conserva el mensaje de ApiException.fromDio',
    () async {
      final stub = Stub(409, {
        'code': 'OTRO_CODIGO',
        'message': 'Mensaje seguro del servidor',
      });
      await expectLater(
        ApiDoctorCancellationRepository(Dio()..httpClientAdapter = stub)
            .cancelShift(301, 'Motivo'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.runtimeType, 'tipo', ApiException)
              .having(
                (e) => e.message,
                'mensaje',
                'Mensaje seguro del servidor',
              ),
        ),
      );
    },
  );
  test('mapea los errores de la operación', () async {
    for (final (status, code, failure, message) in [
      (
        400,
        'VALIDACION',
        DoctorCancellationFailure.validation,
        'Revisá el motivo: es obligatorio y no puede superar los 1000 caracteres.',
      ),
      (
        403,
        'ACCESO_DENEGADO',
        DoctorCancellationFailure.forbidden,
        'Tu cuenta no tiene permiso para cancelar turnos.',
      ),
      (
        403,
        'CONFLICTO_DE_INTERES',
        DoctorCancellationFailure.conflictOfInterest,
        'Tenés una consulta propia agendada en este turno, así que no podés cancelarlo completo. Pedile a la administración que suspenda la fecha.',
      ),
      (
        404,
        'NO_ENCONTRADO',
        DoctorCancellationFailure.notFound,
        'No encontramos este turno entre los tuyos. Se actualizó la lista.',
      ),
      (
        409,
        'TURNO_NO_SUSPENDIBLE',
        DoctorCancellationFailure.shiftNotCancellable,
        'Este turno ya no se puede cancelar: ya está suspendido o su fecha pasó. Se actualizó la lista.',
      ),
      (
        409,
        'CANCELACION_FUERA_DE_PLAZO',
        DoctorCancellationFailure.outsideWindow,
        'No se puede cancelar el turno completo porque hay consultas a menos de 2 horas de su hora. No se canceló ninguna. Si es un imprevisto, coordinalo con la administración.',
      ),
    ]) {
      final stub = Stub(status, {
        'code': code,
        'message': 'texto del servidor',
      });
      await expectLater(
        ApiDoctorCancellationRepository(Dio()..httpClientAdapter = stub)
            .cancelShift(301, 'x'),
        throwsA(
          isA<DoctorCancellationException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.message, 'message', message),
        ),
      );
    }
  });
}
