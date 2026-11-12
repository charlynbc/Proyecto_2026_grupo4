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
  _StubAdapter.json(this.status, this.body) : noConnection = false;

  _StubAdapter.offline() : status = 0, body = null, noConnection = true;

  final int status;
  final Object? body;
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

const _overlapText =
    'Alguna de las fechas elegidas se superpone con otro turno del consultorio '
    'nuevo. Revisá la vista previa y desmarcá esas fechas.';
const _bookedText =
    'Hay consultas agendadas en las fechas elegidas. Revisá la vista previa y '
    'confirmá el cambio para continuar.';
const _invalidText =
    'No pudimos aplicar el cambio. Actualizá la vista previa e intentá de '
    'nuevo.';
const _notFoundText =
    'No encontramos lo que buscabas. Puede que ya no exista: volvé al listado '
    'y probá de nuevo.';

/// Mensajes como los da el servidor real: con fecha ISO, corchetes de lista y
/// el nombre técnico del campo.
const _serverOverlap =
    'Se encontraron solapamientos: fecha 2026-10-20, número 1 con número '
    'existente 1';
const _serverBooked =
    'Hay consultas agendadas en las fechas [2026-11-11, 2026-11-18]. '
    'Confirmá el cambio para continuar.';
const _serverInvalid = 'turnoIds debe incluir IDs válidos y únicos';
const _serverNotFound = 'No existe el consultorio indicado';

/// El texto que ve el usuario no trae datos técnicos.
Matcher _withoutTechnicalData(String text) => isA<ApiException>()
    .having((e) => e.message, 'message', text)
    .having((e) => e.message, 'sin turnoIds', isNot(contains('turnoIds')))
    .having((e) => e.message, 'sin corchetes', isNot(contains('[')))
    .having(
      (e) => e.message,
      'sin fecha aaaa-mm-dd',
      isNot(matches(RegExp(r'\d{4}-\d{2}-\d{2}'))),
    );

void main() {
  test('pide POST de vista previa, sin modificar turnos', () async {
    final (repository, adapter) = _ok(200, {
      'fechas': [
        {
          'turnoId': 301,
          'fecha': '2026-11-11',
          'estado': 'ACTIVO',
          'consultasAgendadas': 2,
          'solapamientos': [
            {'numeroPropio': 1, 'numeroExistente': 3},
          ],
        },
      ],
    });

    final preview = await repository.previewClinicChange(120, 7);

    expect(adapter.last!.method, 'POST');
    expect(
      adapter.last!.path,
      '/api/turnos-semanales/120/consultorio/vista-previa',
    );
    expect(adapter.last!.data, {'consultorioId': 7});
    expect(preview.dates.single.shiftId, 301);
    expect(preview.dates.single.requiresConfirmation, isTrue);
    expect(preview.dates.single.hasOverlaps, isTrue);
  });

  test('pide PATCH con consultorioId', () async {
    final (repository, adapter) = _ok(200, weeklyShiftJson());

    await repository.changeClinic(120, 5);

    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.path, '/api/turnos-semanales/120');
    expect(adapter.last!.data, {'consultorioId': 5});
  });

  test('PATCH parcial manda turnoIds y confirmarConConsultas', () async {
    final (repository, adapter) = _ok(200, weeklyShiftJson());

    await repository.changeClinic(
      120,
      7,
      turnoIds: [301, 303],
      confirmarConConsultas: true,
    );

    expect(adapter.last!.method, 'PATCH');
    expect(adapter.last!.data, {
      'consultorioId': 7,
      'turnoIds': [301, 303],
      'confirmarConConsultas': true,
    });
  });

  test('PATCH parcial sin confirmación no envía el flag', () async {
    final (repository, adapter) = _ok(200, weeklyShiftJson());

    await repository.changeClinic(120, 7, turnoIds: [301]);

    expect(adapter.last!.data, {
      'consultorioId': 7,
      'turnoIds': [301],
    });
  });

  test('el 200 se lee como la configuración', () async {
    final (repository, _) = _ok(200, weeklyShiftJson());

    final shift = await repository.changeClinic(120, 5);

    expect(shift.id, 120);
    expect(shift.clinic.id, 5);
    expect(shift.clinic.name, 'Consultorio 5');
    expect(shift.clinic.location, 'Piso 2, ala norte');
  });

  test('400 VALIDACION muestra el texto propio, no el del servidor', () async {
    final (repository, _) = _ok(400, {
      'code': 'VALIDACION',
      'message': _serverInvalid,
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        allOf(
          isA<ShiftValidationException>(),
          _withoutTechnicalData(_invalidText),
        ),
      ),
    );
  });

  test('404 NO_ENCONTRADO muestra el texto propio', () async {
    final (repository, _) = _ok(404, {
      'code': 'NO_ENCONTRADO',
      'message': _serverNotFound,
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        allOf(
          isA<ShiftNotFoundException>(),
          _withoutTechnicalData(_notFoundText),
        ),
      ),
    );
  });

  test('409 TURNO_NO_MODIFICABLE muestra el texto propio', () async {
    final (repository, _) = _ok(409, {
      'code': 'TURNO_NO_MODIFICABLE',
      'message': _serverBooked,
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        allOf(
          isA<ShiftNotModifiableException>(),
          _withoutTechnicalData(_bookedText),
        ),
      ),
    );
  });

  test('409 SOLAPAMIENTO_TURNO muestra el texto propio', () async {
    final (repository, _) = _ok(409, {
      'code': 'SOLAPAMIENTO_TURNO',
      'message': _serverOverlap,
    });

    await expectLater(
      repository.changeClinic(120, 5),
      throwsA(
        allOf(
          isA<OverlappingShiftException>(),
          _withoutTechnicalData(_overlapText),
        ),
      ),
    );
  });

  test('la vista previa muestra el texto propio en el 400 y el 404', () async {
    final (invalid, _) = _ok(400, {
      'code': 'VALIDACION',
      'message': _serverInvalid,
    });
    await expectLater(
      invalid.previewClinicChange(120, 5),
      throwsA(
        allOf(
          isA<ShiftValidationException>(),
          _withoutTechnicalData(_invalidText),
        ),
      ),
    );

    final (missing, _) = _ok(404, {
      'code': 'NO_ENCONTRADO',
      'message': _serverNotFound,
    });
    await expectLater(
      missing.previewClinicChange(120, 5),
      throwsA(
        allOf(
          isA<ShiftNotFoundException>(),
          _withoutTechnicalData(_notFoundText),
        ),
      ),
    );
  });

  test(
    'un código fuera del contrato conserva el mensaje del servidor',
    () async {
      final (repository, _) = _ok(409, {
        'code': 'OTRO_CODIGO',
        'message': 'Mensaje del servidor',
      });

      await expectLater(
        repository.changeClinic(120, 5),
        throwsA(
          isA<ApiException>()
              .having((e) => e.runtimeType, 'ApiException liso', ApiException)
              .having((e) => e.message, 'message', 'Mensaje del servidor'),
        ),
      );
    },
  );

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
