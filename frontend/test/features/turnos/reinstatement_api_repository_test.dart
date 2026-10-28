import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/turnos/repositories/reinstatement_api_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_reinstatement_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
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

(ApiShiftReinstatementRepository, _StubAdapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiShiftReinstatementRepository(dio), adapter);
}

ShiftReinstatement _request() => ShiftReinstatement(
  doctorId: 17,
  specialtyId: 3,
  fromDate: DateTime.utc(2026, 10, 20),
  toDate: DateTime.utc(2026, 11, 3),
  shiftIds: const [7, 9],
);

Map<String, Object?> _okBody() => {
  'turnos': [
    {'turnoId': 7, 'fecha': '2026-10-20'},
    {'turnoId': 9, 'fecha': '2026-10-27'},
  ],
  'consultasCanceladas': 0,
};

void main() {
  test('con los turnos 7 y 9 manda el filtro completo e ids', () async {
    final (repository, adapter) = _repository(200, _okBody());

    final result = await repository.reinstate(_request());

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.path, '/api/turnos/rehabilitaciones');
    expect(adapter.last!.data, {
      'filtro': {
        'medicoId': 17,
        'especialidadId': 3,
        'fechaDesde': '2026-10-20',
        'fechaHasta': '2026-11-03',
      },
      'ids': [7, 9],
    });
    expect(result.cancelledAppointments, 0);
    expect(result.shifts.map((shift) => shift.id), [7, 9]);
    expect(result.shifts.map((shift) => shift.date), [
      DateTime.utc(2026, 10, 20),
      DateTime.utc(2026, 10, 27),
    ]);
  });

  test(
    'los tres 409 son errores distintos y cada uno conserva su mensaje',
    () async {
      const overlap =
          'Los horarios se cruzan con un turno que ya está habilitado. '
          'Dejá fuera de la selección los turnos que se pisan y volvé a intentar.';
      const inactive =
          'Ese médico no está activo, así que no se pueden volver a habilitar '
          'sus turnos. Elegí otro médico.';
      const notReinstatable =
          'Alguno de los turnos elegidos no se puede volver a habilitar: '
          'no está suspendido o la fecha ya pasó. Elegí otros de la lista.';

      Future<Object> failWith(String code, String message) async {
        final (repository, _) = _repository(409, {
          'code': code,
          'message': message,
        });
        try {
          await repository.reinstate(_request());
        } catch (error) {
          return error;
        }
        throw StateError('Tenía que fallar');
      }

      final overlapError = await failWith('SOLAPAMIENTO_TURNO', overlap);
      final inactiveError = await failWith('MEDICO_INACTIVO', inactive);
      final blockedError = await failWith(
        'TURNO_NO_REHABILITABLE',
        notReinstatable,
      );

      expect(overlapError, isA<OverlappingShiftException>());
      expect((overlapError as ApiException).message, overlap);
      expect(inactiveError, isA<InactiveDoctorException>());
      expect((inactiveError as ApiException).message, inactive);
      expect(blockedError, isA<ShiftNotReinstatableException>());
      expect((blockedError as ApiException).message, notReinstatable);
      expect({overlap, inactive, notReinstatable}, hasLength(3));
    },
  );

  test('se distinguen por el code, no por el texto del mensaje', () async {
    const same = 'Revisá la selección y volvé a intentar.';

    Future<Object> failWith(String code) async {
      final (repository, _) = _repository(409, {
        'code': code,
        'message': same,
      });
      try {
        await repository.reinstate(_request());
      } catch (error) {
        return error;
      }
      throw StateError('Tenía que fallar');
    }

    expect(
      await failWith('SOLAPAMIENTO_TURNO'),
      isA<OverlappingShiftException>(),
    );
    expect(await failWith('MEDICO_INACTIVO'), isA<InactiveDoctorException>());
    expect(
      await failWith('TURNO_NO_REHABILITABLE'),
      isA<ShiftNotReinstatableException>(),
    );
  });
}
