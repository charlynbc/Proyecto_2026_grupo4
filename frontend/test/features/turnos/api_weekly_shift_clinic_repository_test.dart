import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/turnos/repositories/api_weekly_shift_clinic_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/weekly_shift_clinic_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'models/shift_json_test.dart' show weeklyShiftJson;

/// Adaptador de dio que anota el pedido y responde con lo indicado, sin red.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter.json(this.status, this.body) : raw = null, noConnection = false;

  _StubAdapter.raw(this.status, this.raw) : body = null, noConnection = false;

  _StubAdapter.offline()
    : status = 0,
      body = null,
      raw = null,
      noConnection = true;

  final int status;
  final Object? body;
  final String? raw;
  final bool noConnection;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    if (noConnection) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final isRaw = raw != null;
    return ResponseBody.fromString(
      isRaw ? raw! : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [
          isRaw ? 'text/html' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiWeeklyShiftClinicRepository, _StubAdapter) _repository(
  _StubAdapter adapter,
) {
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiWeeklyShiftClinicRepository(dio), adapter);
}

(ApiWeeklyShiftClinicRepository, _StubAdapter) _ok(int status, Object? body) =>
    _repository(_StubAdapter.json(status, body));

Matcher get _genericError => isA<ApiException>()
    .having((e) => e.runtimeType, 'es un ApiException liso', ApiException)
    .having((e) => e.message, 'message', kApiGenericMessage);

void main() {
  test('pide PATCH con consultorioId', () async {
    final (repository, adapter) = _ok(200, weeklyShiftJson());

    await repository.changeClinic(120, 5);

    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.path, '/api/turnos-semanales/120');
    expect(adapter.last!.data, {'consultorioId': 5});
  });

  test('el 200 se lee como la configuración', () async {
    final (repository, _) = _ok(200, weeklyShiftJson());

    final shift = await repository.changeClinic(120, 5);

    expect(shift.id, 120);
    expect(shift.clinic.id, 5);
    expect(shift.clinic.name, 'Consultorio 5');
    expect(shift.clinic.location, 'Piso 2, ala norte');
  });

  test('400 VALIDACION trae el mensaje del servidor', () async {
    final (repository, _) = _ok(400, {
      'code': 'VALIDACION',
      'message': 'Faltan datos obligatorios o no son válidos',
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        isA<ShiftValidationException>().having(
          (e) => e.message,
          'message',
          'Faltan datos obligatorios o no son válidos',
        ),
      ),
    );
  });

  test('404 NO_ENCONTRADO trae el mensaje del servidor', () async {
    final (repository, _) = _ok(404, {
      'code': 'NO_ENCONTRADO',
      'message': 'No existe el turno semanal indicado',
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        isA<ShiftNotFoundException>().having(
          (e) => e.message,
          'message',
          'No existe el turno semanal indicado',
        ),
      ),
    );
  });

  test('409 TURNO_NO_MODIFICABLE trae el mensaje del servidor', () async {
    const message =
        'El turno semanal ya finalizó; no tiene fechas actuales ni futuras '
        'por modificar';
    final (repository, _) = _ok(409, {
      'code': 'TURNO_NO_MODIFICABLE',
      'message': message,
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        isA<ShiftNotModifiableException>().having(
          (e) => e.message,
          'message',
          message,
        ),
      ),
    );
  });

  test('409 SOLAPAMIENTO_TURNO trae el mensaje del servidor', () async {
    const message =
        'Se encontraron solapamientos: fecha 2026-10-20, número 1 con número '
        'existente 1';
    final (repository, _) = _ok(409, {
      'code': 'SOLAPAMIENTO_TURNO',
      'message': message,
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        isA<OverlappingShiftException>().having(
          (e) => e.message,
          'message',
          message,
        ),
      ),
    );
  });

  test('sin conexión avisa que no hay red', () async {
    final (repository, _) = _repository(_StubAdapter.offline());

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        isA<ApiException>()
            .having((e) => e.runtimeType, 'ApiException liso', ApiException)
            .having((e) => e.message, 'message', kApiNoConnectionMessage),
      ),
    );
  });

  test('un 500 con cuerpo vacío es el error genérico', () async {
    final (repository, _) = _ok(500, null);

    await expectLater(repository.changeClinic(120, 5), throwsA(_genericError));
  });
}
