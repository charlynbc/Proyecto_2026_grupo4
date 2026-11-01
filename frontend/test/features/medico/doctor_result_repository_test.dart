import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/medico/models/doctor_appointment_result.dart';
import 'package:agenda_medica/features/medico/repositories/api_doctor_result_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_result_repository.dart';
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

(ApiDoctorResultRepository, _StubAdapter) _api(int status, Object? body) {
  final adapter = _StubAdapter(status, body);
  return (
    ApiDoctorResultRepository(Dio()..httpClientAdapter = adapter),
    adapter,
  );
}

const _noShowRequest = AppointmentResultRequest(
  outcome: ConsultationOutcome.noShow,
);

Map<String, Object?> _error(String code) => {
  'code': code,
  'message': 'texto del servidor',
};

void main() {
  group('cuerpo del pedido', () {
    test('ATENDIDA con afección, tratamiento y un pase sin tocar la '
        'vigencia', () {
      const request = AppointmentResultRequest(
        outcome: ConsultationOutcome.attended,
        condition: 'gripe',
        treatment: 'reposo',
        referrals: [ReferralRequest(specialtyId: 3)],
      );

      expect(request.toJson(), {
        'resultado': 'ATENDIDA',
        'afeccion': 'gripe',
        'tratamiento': 'reposo',
        'pases': [
          {'especialidadDestinoId': 3, 'vigenciaDias': 90},
        ],
      });
    });

    test('NO_SE_PRESENTO es exactamente {resultado}, aunque haya texto', () {
      const request = AppointmentResultRequest(
        outcome: ConsultationOutcome.noShow,
        condition: 'gripe',
        treatment: 'reposo',
        notes: 'nota',
        referrals: [ReferralRequest(specialtyId: 3, validityDays: 30)],
      );

      expect(request.toJson(), {'resultado': 'NO_SE_PRESENTO'});
    });

    test('ATENDIDA omite tratamiento, observaciones y pases vacíos', () {
      const request = AppointmentResultRequest(
        outcome: ConsultationOutcome.attended,
        condition: 'gripe',
        treatment: '',
        notes: '',
      );

      expect(request.toJson(), {'resultado': 'ATENDIDA', 'afeccion': 'gripe'});
    });
  });

  group('respuesta', () {
    test('NO_SE_PRESENTO sin atencionId ni pases se parsea', () async {
      final (repository, adapter) = _api(200, {
        'consultaId': 15,
        'estado': 'NO_SE_PRESENTO',
        'atencionId': null,
        'registradoEn': '2026-10-26T10:00:00-03:00',
        'pases': <Object>[],
      });

      final result = await repository.register(15, _noShowRequest);

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/medico/consultas/15/resultado');
      expect(adapter.last!.data, {'resultado': 'NO_SE_PRESENTO'});
      expect(result.appointmentId, 15);
      expect(result.outcome, ConsultationOutcome.noShow);
      expect(result.attentionId, isNull);
      expect(result.referrals, isEmpty);
    });

    test('ATENDIDA con un pase lo parsea con destino y vencimiento', () async {
      final (repository, _) = _api(200, {
        'consultaId': 15,
        'estado': 'ATENDIDA',
        'atencionId': 8,
        'registradoEn': '2026-10-26T10:00:00-03:00',
        'pases': [
          {
            'id': 7,
            'especialidadDestino': {
              'id': 3,
              'nombre': 'Cardiología',
              'requierePase': true,
            },
            'emitidoEn': '2026-10-26T10:00:00-03:00',
            'venceEl': '2027-01-24',
          },
        ],
      });

      final result = await repository.register(
        15,
        const AppointmentResultRequest(
          outcome: ConsultationOutcome.attended,
          condition: 'gripe',
        ),
      );

      expect(result.outcome, ConsultationOutcome.attended);
      expect(result.attentionId, 8);
      expect(result.referrals, hasLength(1));
      expect(result.referrals.single.id, 7);
      expect(result.referrals.single.specialty.name, 'Cardiología');
      expect(result.referrals.single.expiresOn, DateTime.utc(2027, 1, 24));
    });

    test('un estado desconocido es el error genérico', () async {
      final (repository, _) = _api(200, {
        'consultaId': 15,
        'estado': 'OTRO',
        'atencionId': null,
        'registradoEn': '2026-10-26T10:00:00-03:00',
        'pases': <Object>[],
      });

      await expectLater(
        repository.register(15, _noShowRequest),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            kApiGenericMessage,
          ),
        ),
      );
    });
  });

  group('errores por code', () {
    final cases = <(int, String, Matcher)>[
      (400, 'VALIDACION', isA<ResultValidationException>()),
      (403, 'CONFLICTO_DE_INTERES', isA<ConflictOfInterestException>()),
      (404, 'NO_ENCONTRADO', isA<ResultAppointmentNotFoundException>()),
      (409, 'CONSULTA_NO_AGENDADA', isA<AppointmentNotScheduledException>()),
      (409, 'CONSULTA_NO_ES_DE_HOY', isA<AppointmentNotTodayException>()),
      (409, 'SIN_AVISO_LLEGADA', isA<NoArrivalNoticeException>()),
      (409, 'PASE_DUPLICADO', isA<DuplicateReferralException>()),
    ];
    for (final (status, code, matcher) in cases) {
      test('$status $code', () async {
        final (repository, _) = _api(status, _error(code));

        await expectLater(
          repository.register(15, _noShowRequest),
          throwsA(matcher),
        );
      });
    }
  });
}
