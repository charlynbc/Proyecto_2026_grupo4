import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/medico/repositories/api_doctor_patient_history_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_patient_history_repository.dart';
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

(ApiDoctorPatientHistoryRepository, _StubAdapter) _api(
  int status,
  Object? body,
) {
  final adapter = _StubAdapter(status, body);
  return (
    ApiDoctorPatientHistoryRepository(Dio()..httpClientAdapter = adapter),
    adapter,
  );
}

Map<String, Object?> _error(String code) => {
  'code': code,
  'message': 'Mensaje inventado por el servidor.',
};

Map<String, Object?> _entry() => {
  'idAtencion': 5530,
  'fechaAtencion': '2026-10-20',
  'medicoId': 17,
  'medicoNombre': 'Marta',
  'medicoApellido': 'Rodríguez',
  'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  'afeccion': 'Hipertensión arterial leve',
  'tratamiento': 'Control de dieta y medicación indicada',
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

void main() {
  test('consulta la ruta del socio sin parámetros', () async {
    final (repository, adapter) = _api(200, [_entry()]);

    await repository.history(21);

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/medico/pacientes/21/historia-clinica');
    expect(adapter.last!.queryParameters, isEmpty);
  });

  test('lee la atención y el pase de la historia clínica', () async {
    final (repository, _) = _api(200, [_entry()]);

    final entries = await repository.history(21);

    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.id, 5530);
    expect(entry.attendedOn, DateTime.utc(2026, 10, 20));
    expect(entry.doctorFullName, 'Marta Rodríguez');
    expect(entry.specialty.name, 'Cardiología');
    expect(entry.condition, 'Hipertensión arterial leve');
    expect(entry.treatment, 'Control de dieta y medicación indicada');
    expect(entry.observations, isNull);
    expect(entry.referrals, hasLength(1));
    expect(entry.referrals.single.specialty.name, 'Nutrición');
    expect(entry.referrals.single.expiresOn, DateTime.utc(2027, 1, 18));
  });

  test('una respuesta vacía da una lista vacía', () async {
    final (repository, _) = _api(200, []);

    expect(await repository.history(21), isEmpty);
  });

  test('ids cero y negativo dan validation sin llamar al servidor', () async {
    final (repository, adapter) = _api(200, []);

    for (final id in [0, -2]) {
      await expectLater(
        repository.history(id),
        throwsA(
          isA<DoctorPatientHistoryException>().having(
            (error) => error.failure,
            'failure',
            DoctorPatientHistoryFailure.validation,
          ),
        ),
      );
    }

    expect(adapter.last, isNull);
  });

  test('un objeto en vez de una lista da el error genérico', () async {
    final (repository, _) = _api(200, {
      'items': [_entry()],
    });

    await expectLater(
      repository.history(21),
      throwsA(
        isA<ApiException>()
            .having((error) => error.message, 'message', kApiGenericMessage)
            .having(
              (error) => error,
              'tipo',
              isNot(isA<DoctorPatientHistoryException>()),
            ),
      ),
    );
  });

  test('un item sin afeccion da el error genérico', () async {
    final entry = _entry()..remove('afeccion');
    final (repository, _) = _api(200, [entry]);

    await expectLater(
      repository.history(21),
      throwsA(
        isA<ApiException>()
            .having((error) => error.message, 'message', kApiGenericMessage)
            .having(
              (error) => error,
              'tipo',
              isNot(isA<DoctorPatientHistoryException>()),
            ),
      ),
    );
  });

  for (final (code, status, failure, message) in [
    (
      'VALIDACION',
      400,
      DoctorPatientHistoryFailure.validation,
      'No pudimos identificar al paciente. Volvé a Mis turnos e intentá de nuevo.',
    ),
    (
      'ACCESO_DENEGADO',
      403,
      DoctorPatientHistoryFailure.forbidden,
      'Tu cuenta no tiene permiso para consultar historias clínicas.',
    ),
    (
      'CONFLICTO_DE_INTERES',
      403,
      DoctorPatientHistoryFailure.conflictOfInterest,
      'No podés consultar tu propia historia clínica desde la cuenta de médico.',
    ),
    (
      'NO_ENCONTRADO',
      404,
      DoctorPatientHistoryFailure.notFound,
      'No podés ver la historia clínica de este paciente en este momento. Solo está disponible mientras tengas con él una consulta agendada que no haya terminado.',
    ),
  ]) {
    test('$status $code da el mensaje propio de la falla', () async {
      final (repository, _) = _api(status, _error(code));

      await expectLater(
        repository.history(21),
        throwsA(
          isA<DoctorPatientHistoryException>()
              .having((error) => error.failure, 'failure', failure)
              .having((error) => error.message, 'message', message),
        ),
      );
    });
  }

  test('un code desconocido conserva el ApiException del servidor', () async {
    final (repository, _) = _api(500, _error('OTRO'));

    await expectLater(
      repository.history(21),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.message,
              'message',
              'Mensaje inventado por el servidor.',
            )
            .having(
              (error) => error,
              'tipo',
              isNot(isA<DoctorPatientHistoryException>()),
            ),
      ),
    );
  });
}
