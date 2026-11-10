import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/medico/repositories/api_doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_cancellation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body, {this.raw});

  final int status;
  final Object? body;

  /// Cuerpo tal cual, sin `jsonEncode`. Sirve para un 200 vacío o un JSON roto.
  final String? raw;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      raw ?? jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiDoctorCancellationRepository, _StubAdapter) _api(
  int status,
  Object? body, {
  String? raw,
}) {
  final adapter = _StubAdapter(status, body, raw: raw);
  return (
    ApiDoctorCancellationRepository(Dio()..httpClientAdapter = adapter),
    adapter,
  );
}

const _validationMessage =
    'Revisá el motivo: es obligatorio y no puede superar los 1000 caracteres.';

const _okBody = {
  'consultaId': 9001,
  'estado': 'CANCELADA_INSTITUCION',
  'canceladaEn': '2026-10-30T09:03:10-03:00',
  'paseDevuelto': true,
};

Map<String, Object?> _error(String code) => {
  'code': code,
  'message': 'texto del servidor',
};

Matcher _plainApi([String message = kApiGenericMessage]) => isA<ApiException>()
    .having((e) => e.runtimeType, 'es un ApiException liso', ApiException)
    .having((e) => e.message, 'message', message);

Matcher _failure(DoctorCancellationFailure failure, String message) =>
    isA<DoctorCancellationException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.message, 'message', message);

void main() {
  test('pide POST con el motivo y lee la cancelación', () async {
    final (repository, adapter) = _api(200, _okBody);

    final result = await repository.cancelAppointment(
      9001,
      'Imprevisto de guardia',
    );

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/medico/consultas/9001/cancelar');
    expect(adapter.last!.data, {'motivo': 'Imprevisto de guardia'});
    expect(result.appointmentId, 9001);
    expect(result.status, 'CANCELADA_INSTITUCION');
    expect(result.cancelledAt, DateTime.utc(2026, 10, 30, 12, 3, 10));
    expect(result.referralReturned, isTrue);
  });

  test('el motivo viaja recortado', () async {
    final (repository, adapter) = _api(200, _okBody);

    await repository.cancelAppointment(9001, '  Imprevisto  ');

    expect(adapter.last!.data, {'motivo': 'Imprevisto'});
  });

  test('un motivo de 1000 caracteres se manda', () async {
    final reason = 'a' * 1000;
    final (repository, adapter) = _api(200, _okBody);

    await repository.cancelAppointment(9001, reason);

    expect(adapter.last!.data, {'motivo': reason});
  });

  test('un motivo de 1001 caracteres es validación y no llama', () async {
    final (repository, adapter) = _api(200, _okBody);

    await expectLater(
      repository.cancelAppointment(9001, 'a' * 1001),
      throwsA(
        _failure(DoctorCancellationFailure.validation, _validationMessage),
      ),
    );
    expect(adapter.last, isNull);
  });

  for (final reason in ['', '   ']) {
    test("el motivo '$reason' es validación y no llama", () async {
      final (repository, adapter) = _api(200, _okBody);

      await expectLater(
        repository.cancelAppointment(9001, reason),
        throwsA(
          _failure(DoctorCancellationFailure.validation, _validationMessage),
        ),
      );
      expect(adapter.last, isNull);
    });
  }

  for (final id in [0, -3]) {
    test('el id $id es validación y no llama', () async {
      final (repository, adapter) = _api(200, _okBody);

      await expectLater(
        repository.cancelAppointment(id, 'Imprevisto de guardia'),
        throwsA(
          _failure(DoctorCancellationFailure.validation, _validationMessage),
        ),
      );
      expect(adapter.last, isNull);
    });
  }

  test('un estado distinto es el error genérico', () async {
    final (repository, _) = _api(200, {
      'consultaId': 9001,
      'estado': 'ATENDIDA',
      'canceladaEn': '2026-10-30T09:03:10-03:00',
      'paseDevuelto': true,
    });

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi()),
    );
  });

  test('sin canceladaEn es el error genérico', () async {
    final (repository, _) = _api(200, {
      'consultaId': 9001,
      'estado': 'CANCELADA_INSTITUCION',
      'paseDevuelto': true,
    });

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi()),
    );
  });

  test('paseDevuelto que no es booleano es el error genérico', () async {
    final (repository, _) = _api(200, {
      'consultaId': 9001,
      'estado': 'CANCELADA_INSTITUCION',
      'canceladaEn': '2026-10-30T09:03:10-03:00',
      'paseDevuelto': 'si',
    });

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi()),
    );
  });

  final errors = <(int, String, DoctorCancellationFailure, String)>[
    (
      400,
      'VALIDACION',
      DoctorCancellationFailure.validation,
      _validationMessage,
    ),
    (
      403,
      'ACCESO_DENEGADO',
      DoctorCancellationFailure.forbidden,
      'Tu cuenta no tiene permiso para cancelar consultas.',
    ),
    (
      403,
      'CONFLICTO_DE_INTERES',
      DoctorCancellationFailure.conflictOfInterest,
      'No podés cancelar una consulta en la que vos sos el socio. '
          'Pedile a otra persona que lo haga.',
    ),
    (
      404,
      'NO_ENCONTRADO',
      DoctorCancellationFailure.notFound,
      'No encontramos esta consulta entre las tuyas. Se actualizó la lista.',
    ),
    (
      409,
      'CONSULTA_NO_AGENDADA',
      DoctorCancellationFailure.notScheduled,
      'Esta consulta ya no está agendada, así que no se puede cancelar. '
          'Se actualizó la lista.',
    ),
    (
      409,
      'CANCELACION_FUERA_DE_PLAZO',
      DoctorCancellationFailure.outsideWindow,
      'Ya no se puede cancelar: faltan menos de 2 horas para la hora del '
          'número. Si es un imprevisto, coordinalo con la administración.',
    ),
  ];
  for (final (status, code, failure, message) in errors) {
    test('$status $code usa el mensaje propio', () async {
      final (repository, _) = _api(status, _error(code));

      await expectLater(
        repository.cancelAppointment(9001, 'Imprevisto de guardia'),
        throwsA(_failure(failure, message)),
      );
    });
  }

  test('un 200 sin cuerpo es el error genérico', () async {
    final (repository, _) = _api(200, null, raw: '');

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi()),
    );
  });

  test('un JSON roto es el error genérico', () async {
    final (repository, _) = _api(200, null, raw: '{');

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi()),
    );
  });

  test('una respuesta sin consultaId es el error genérico', () async {
    final (repository, _) = _api(200, {
      'estado': 'CANCELADA_INSTITUCION',
      'canceladaEn': '2026-10-30T09:03:10-03:00',
      'paseDevuelto': true,
    });

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi()),
    );
  });

  test('401 NO_AUTENTICADO no tiene rama propia', () async {
    final (repository, _) = _api(401, _error('NO_AUTENTICADO'));

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi('texto del servidor')),
    );
  });

  test('un 500 es un ApiException liso', () async {
    final (repository, _) = _api(500, _error('ERROR_INTERNO'));

    await expectLater(
      repository.cancelAppointment(9001, 'Imprevisto de guardia'),
      throwsA(_plainApi('texto del servidor')),
    );
  });
}
