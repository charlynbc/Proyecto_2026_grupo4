import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/turnos/models/suspension_filter.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_api_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_suspension_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador de dio que anota el pedido y responde con lo indicado, sin red.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter.json(this.status, this.body) : noConnection = false;

  /// Sin conexión: el pedido ni llega al servidor.
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

(ApiShiftSuspensionRepository, _StubAdapter) _repository(
  _StubAdapter adapter,
) {
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiShiftSuspensionRepository(dio), adapter);
}

(ApiShiftSuspensionRepository, _StubAdapter) _ok(int status, Object? body) =>
    _repository(_StubAdapter.json(status, body));

(ApiShiftSuspensionRepository, _StubAdapter) _error(
  int status,
  String code,
  String message,
) => _ok(status, {'code': code, 'message': message});

final _filter = SuspensionFilter(
  doctorId: 17,
  specialtyId: 3,
  fromDate: DateTime.utc(2026, 11, 4),
  toDate: DateTime.utc(2026, 11, 6),
);

const _previewJson = {
  'fechasAfectadas': [
    {
      'turnoId': 7,
      'fecha': '2026-11-04',
      'horaInicio': '09:00',
      'horaFin': '11:40',
      'consultasACancelar': 2,
    },
    {
      'turnoId': 9,
      'fecha': '2026-11-06',
      'horaInicio': '09:00',
      'horaFin': '11:40',
      'consultasACancelar': 1,
    },
  ],
  'cantidadConsultasACancelar': 3,
};

const _resultJson = {
  'turnos': [
    {'turnoId': 7, 'fecha': '2026-11-04'},
    {'turnoId': 9, 'fecha': '2026-11-06'},
  ],
  'consultasCanceladas': 3,
};

Future<void> _suspend(
  ApiShiftSuspensionRepository repository, {
  String? observation,
}) => repository.suspend(
  filter: _filter,
  ids: const [7, 9],
  observation: observation,
  confirmedCount: 3,
);

/// El error que tira [call], o `null` si termina bien.
Future<Object?> _thrown(Future<void> call) =>
    call.then<Object?>((_) => null, onError: (Object e) => e);

void main() {
  group('previsualizar', () {
    test(
      'envia POST a la ruta de previsualizar con el cuerpo {ids: [7, 9]}',
      () async {
        final (repository, adapter) = _ok(200, _previewJson);

        await repository.preview(const [7, 9]);

        expect(adapter.last!.method, 'POST');
        expect(adapter.last!.path, '/api/turnos/suspensiones/previsualizar');
        expect(adapter.last!.data, {
          'ids': [7, 9],
        });
      },
    );

    test('interpreta 2 fechas y un total de 3 consultas', () async {
      final (repository, _) = _ok(200, _previewJson);

      final preview = await repository.preview(const [7, 9]);

      expect(preview.affectedDates, hasLength(2));
      expect(preview.totalAppointments, 3);
      final first = preview.affectedDates[0];
      expect(first.shiftId, 7);
      expect(first.date, DateTime.utc(2026, 11, 4));
      expect(first.startMinutes, 9 * 60);
      expect(first.endMinutes, 11 * 60 + 40);
      expect(first.appointmentsToCancel, 2);
      expect(preview.affectedDates[1].shiftId, 9);
      expect(preview.affectedDates[1].appointmentsToCancel, 1);
    });

    test('una respuesta sin fechasAfectadas es el error generico', () async {
      final (repository, _) = _ok(200, {'cantidadConsultasACancelar': 3});

      await expectLater(
        repository.preview(const [7]),
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

  group('suspender', () {
    test(
      'envia POST con filtro, ids, cantidadConfirmada y observacion recortada',
      () async {
        final (repository, adapter) = _ok(200, _resultJson);

        await _suspend(repository, observation: '  aviso  ');

        expect(adapter.last!.method, 'POST');
        expect(adapter.last!.path, '/api/turnos/suspensiones');
        expect(adapter.last!.data, {
          'filtro': {
            'medicoId': 17,
            'especialidadId': 3,
            'fechaDesde': '2026-11-04',
            'fechaHasta': '2026-11-06',
          },
          'ids': [7, 9],
          'observacion': 'aviso',
          'cantidadConfirmada': 3,
        });
      },
    );

    test('una observacion de solo espacios no se envia', () async {
      final (repository, adapter) = _ok(200, _resultJson);

      await _suspend(repository, observation: '   ');

      final body = adapter.last!.data as Map<String, dynamic>;
      expect(body.containsKey('observacion'), isFalse);
    });

    test('sin observacion no se envia el campo', () async {
      final (repository, adapter) = _ok(200, _resultJson);

      await _suspend(repository);

      final body = adapter.last!.data as Map<String, dynamic>;
      expect(body.containsKey('observacion'), isFalse);
    });

    test('interpreta 2 turnos suspendidos y 3 consultas canceladas', () async {
      final (repository, _) = _ok(200, _resultJson);

      final result = await repository.suspend(
        filter: _filter,
        ids: const [7, 9],
        confirmedCount: 3,
      );

      expect(result.shifts.map((s) => s.shiftId), [7, 9]);
      expect(result.shifts[0].date, DateTime.utc(2026, 11, 4));
      expect(result.cancelledAppointments, 3);
    });
  });

  group('errores', () {
    test(
      '409 CONFIRMACION_DESACTUALIZADA es distinto de TURNO_NO_SUSPENDIBLE',
      () async {
        final (stale, _) = _error(
          409,
          'CONFIRMACION_DESACTUALIZADA',
          'Cambio la cantidad.',
        );
        final (notSuspendable, _) = _error(
          409,
          'TURNO_NO_SUSPENDIBLE',
          'Un turno ya paso.',
        );

        final staleError = await _thrown(_suspend(stale));
        final notSuspendableError = await _thrown(_suspend(notSuspendable));

        expect(staleError, isA<StaleSuspensionConfirmationException>());
        expect(staleError, isNot(isA<ShiftNotSuspendableException>()));
        expect(notSuspendableError, isA<ShiftNotSuspendableException>());
        expect(
          notSuspendableError,
          isNot(isA<StaleSuspensionConfirmationException>()),
        );
        expect((staleError! as ApiException).message, 'Cambio la cantidad.');
        expect(
          (notSuspendableError! as ApiException).message,
          'Un turno ya paso.',
        );
      },
    );

    test('previsualizar tambien distingue TURNO_NO_SUSPENDIBLE', () async {
      final (repository, _) = _error(409, 'TURNO_NO_SUSPENDIBLE', 'Ya paso.');

      await expectLater(
        repository.preview(const [7]),
        throwsA(isA<ShiftNotSuspendableException>()),
      );
    });

    test('400 VALIDACION es ShiftValidationException', () async {
      final (repository, _) = _error(400, 'VALIDACION', 'Dato invalido.');

      await expectLater(
        _suspend(repository),
        throwsA(isA<ShiftValidationException>()),
      );
    });

    test('404 NO_ENCONTRADO es ShiftNotFoundException', () async {
      final (repository, _) = _error(404, 'NO_ENCONTRADO', 'No existe.');

      await expectLater(
        repository.preview(const [7]),
        throwsA(isA<ShiftNotFoundException>()),
      );
    });

    test('sin conexion es ApiException con el mensaje de conexion', () async {
      final (repository, _) = _repository(_StubAdapter.offline());

      await expectLater(
        _suspend(repository),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            kApiNoConnectionMessage,
          ),
        ),
      );
    });
  });
}
