import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agendas/repositories/api_staff_cancellation_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/staff_cancellation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter.json(this.status, Object? body)
    : responseBody = jsonEncode(body);
  _StubAdapter.raw(this.status, this.responseBody);

  final int status;
  final String responseBody;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      responseBody,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiStaffCancellationRepository, _StubAdapter) _repository(
  _StubAdapter adapter,
) {
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiStaffCancellationRepository(dio), adapter);
}

(ApiStaffCancellationRepository, _StubAdapter) _ok(Object? body) =>
    _repository(_StubAdapter.json(200, body));

(ApiStaffCancellationRepository, _StubAdapter) _rawOk(String body) =>
    _repository(_StubAdapter.raw(200, body));

(ApiStaffCancellationRepository, _StubAdapter) _fails(
  int status,
  String code,
  String message,
) => _repository(_StubAdapter.json(status, {'code': code, 'message': message}));

Matcher _staffError(StaffCancellationFailure failure, String message) =>
    isA<StaffCancellationException>()
        .having((error) => error.failure, 'failure', failure)
        .having((error) => error.message, 'message', message);

void main() {
  test(
    'cancel(9001) pide la cancelacion sin cuerpo y lee la respuesta',
    () async {
      final (repository, adapter) = _ok({
        'consultaId': 9001,
        'estado': 'CANCELADA_SOCIO',
        'canceladaEn': '2026-10-30T09:03:10-03:00',
        'paseDevuelto': true,
      });

      final result = await repository.cancel(9001);

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/funcionario/consultas/9001/cancelar');
      expect(adapter.last!.data, isNull);
      expect(result.appointmentId, 9001);
      expect(result.status, 'CANCELADA_SOCIO');
      expect(result.cancelledAt, DateTime.utc(2026, 10, 30, 12, 3, 10));
      expect(result.referralReturned, isTrue);
    },
  );

  group('respuestas mal formadas', () {
    final cases = <({String name, Map<String, Object?> body})>[
      (
        name: 'estado ATENDIDA es error generico',
        body: {
          'consultaId': 9001,
          'estado': 'ATENDIDA',
          'canceladaEn': '2026-10-30T09:03:10-03:00',
          'paseDevuelto': true,
        },
      ),
      (
        name: 'sin canceladaEn es error generico',
        body: {
          'consultaId': 9001,
          'estado': 'CANCELADA_SOCIO',
          'paseDevuelto': true,
        },
      ),
      (
        name: 'paseDevuelto no booleano es error generico',
        body: {
          'consultaId': 9001,
          'estado': 'CANCELADA_SOCIO',
          'canceladaEn': '2026-10-30T09:03:10-03:00',
          'paseDevuelto': 'si',
        },
      ),
    ];

    for (final testCase in cases) {
      test(testCase.name, () async {
        final (repository, _) = _ok(testCase.body);

        await expectLater(
          repository.cancel(9001),
          throwsA(
            _staffError(StaffCancellationFailure.other, kApiGenericMessage),
          ),
        );
      });
    }
  });

  test('respuesta 200 sin cuerpo es error generico', () async {
    final (repository, _) = _rawOk('');

    await expectLater(
      repository.cancel(9001),
      throwsA(_staffError(StaffCancellationFailure.other, kApiGenericMessage)),
    );
  });

  test('respuesta 200 con JSON roto es error generico', () async {
    final (repository, _) = _rawOk('{');

    await expectLater(
      repository.cancel(9001),
      throwsA(_staffError(StaffCancellationFailure.other, kApiGenericMessage)),
    );
  });

  test('respuesta 200 sin consultaId es error generico', () async {
    final (repository, _) = _ok({
      'estado': 'CANCELADA_SOCIO',
      'canceladaEn': '2026-10-30T09:03:10-03:00',
      'paseDevuelto': true,
    });

    await expectLater(
      repository.cancel(9001),
      throwsA(_staffError(StaffCancellationFailure.other, kApiGenericMessage)),
    );
  });

  group('identificadores inválidos', () {
    for (final id in [0, -3]) {
      test('cancel($id) no llama al adaptador', () async {
        final (repository, adapter) = _ok({});

        await expectLater(
          repository.cancel(id),
          throwsA(
            _staffError(
              StaffCancellationFailure.validation,
              kApiGenericMessage,
            ),
          ),
        );
        expect(adapter.last, isNull);
      });
    }
  });

  final errorCases = <_ErrorCase>[
    _ErrorCase(404, 'NO_ENCONTRADO', StaffCancellationFailure.notFound),
    _ErrorCase(
      409,
      'CONSULTA_NO_AGENDADA',
      StaffCancellationFailure.notScheduled,
    ),
    _ErrorCase(
      409,
      'CANCELACION_FUERA_DE_PLAZO',
      StaffCancellationFailure.outsideWindow,
    ),
    _ErrorCase(
      403,
      'CONFLICTO_INTERES',
      StaffCancellationFailure.conflictOfInterest,
    ),
    _ErrorCase(403, 'ACCESO_DENEGADO', StaffCancellationFailure.forbidden),
    _ErrorCase(401, 'NO_AUTENTICADO', StaffCancellationFailure.unauthenticated),
    _ErrorCase(401, 'TOKEN_INVALIDO', StaffCancellationFailure.unauthenticated),
    _ErrorCase(400, 'VALIDACION', StaffCancellationFailure.validation),
    _ErrorCase(500, 'OTRO_ERROR', StaffCancellationFailure.other),
  ];

  group('errores del servidor', () {
    for (final errorCase in errorCases) {
      test('${errorCase.status} ${errorCase.code}', () async {
        const serverMessage = 'El servidor conserva este mensaje.';
        final (repository, _) = _fails(
          errorCase.status,
          errorCase.code,
          serverMessage,
        );

        await expectLater(
          repository.cancel(9001),
          throwsA(_staffError(errorCase.failure, serverMessage)),
        );
      });
    }
  });
}

class _ErrorCase {
  const _ErrorCase(this.status, this.code, this.failure);

  final int status;
  final String code;
  final StaffCancellationFailure failure;
}
