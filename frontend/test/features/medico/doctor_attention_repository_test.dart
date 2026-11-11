import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/medico/models/doctor_attention_query.dart';
import 'package:agenda_medica/features/medico/repositories/api_doctor_attention_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_attention_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class Stub implements HttpClientAdapter {
  Stub(this.status, this.body);
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

final sample = {
  'idAtencion': 5530,
  'fechaAtencion': '2026-10-20',
  'paciente': {
    'id': 21,
    'ci': '45678911',
    'nombre': 'Lucía',
    'apellido': 'Fernández',
  },
  'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  'afeccion': 'Hipertensión arterial leve',
  'tratamiento': null,
  'observaciones': null,
  'pases': [
    {
      'id': 78,
      'especialidad': {'id': 4, 'nombre': 'Nutrición', 'requierePase': true},
      'emitidoEn': '2026-10-20T09:41:00-03:00',
      'venceEl': '2027-01-18',
    },
  ],
};
final query = DoctorAttentionQuery(
  from: DateTime.utc(2026, 10, 1),
  to: DateTime.utc(2026, 10, 31),
);
void main() {
  test('lista y detalle usan rutas y leen el contrato', () async {
    final stub = Stub(200, [sample]);
    final repo = ApiDoctorAttentionRepository(Dio()..httpClientAdapter = stub);
    final result = await repo.list(query);
    expect(stub.last!.path, '/api/medico/atenciones');
    expect(stub.last!.queryParameters, query.toQueryParameters());
    expect(result.single.patient.fullName, 'Lucía Fernández');
    expect(result.single.referrals.single.expiresOn, DateTime.utc(2027, 1, 18));
    final detailStub = Stub(200, sample);
    final detailRepo = ApiDoctorAttentionRepository(
      Dio()..httpClientAdapter = detailStub,
    );
    expect((await detailRepo.get(5530)).id, 5530);
    expect(detailStub.last!.path, '/api/medico/atenciones/5530');
    await expectLater(
      detailRepo.get(0),
      throwsA(
        isA<DoctorAttentionException>().having(
          (e) => e.failure,
          'failure',
          DoctorAttentionFailure.validation,
        ),
      ),
    );
  });
  for (final (status, code, failure) in [
    (400, 'VALIDACION', DoctorAttentionFailure.validation),
    (403, 'ACCESO_DENEGADO', DoctorAttentionFailure.forbidden),
    (404, 'NO_ENCONTRADO', DoctorAttentionFailure.notFound),
  ]) {
    test('mapea $code sin mostrar el texto del servidor', () async {
      final repo = ApiDoctorAttentionRepository(
        Dio()
          ..httpClientAdapter = Stub(status, {
            'code': code,
            'message': 'texto del servidor',
          }),
      );
      await expectLater(
        repo.get(1),
        throwsA(
          isA<DoctorAttentionException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.message, 'message', isNot('texto del servidor')),
        ),
      );
    });
  }
  test('una respuesta inválida produce error genérico', () async {
    final repo = ApiDoctorAttentionRepository(
      Dio()..httpClientAdapter = Stub(200, {'items': []}),
    );
    await expectLater(repo.list(query), throwsA(isA<ApiException>()));
  });
}
