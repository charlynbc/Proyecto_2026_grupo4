import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/repositories/api_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'models/shift_json_test.dart' show doctorJson, weeklyShiftJson;
import 'models/shift_models_test.dart' show shiftJson;

/// Adaptador de dio que anota el pedido y responde con lo indicado, sin red.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter.json(this.status, this.body) : raw = null, noConnection = false;

  /// Una respuesta que no es JSON (por ejemplo, la página de error de un
  /// proxy).
  _StubAdapter.raw(this.status, this.raw) : body = null, noConnection = false;

  /// Sin conexión: el pedido ni llega al servidor.
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

(ApiShiftRepository, _StubAdapter) _repository(_StubAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiShiftRepository(dio), adapter);
}

(ApiShiftRepository, _StubAdapter) _ok(int status, Object? body) =>
    _repository(_StubAdapter.json(status, body));

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

NewWeeklyShift _newWeeklyShift() => NewWeeklyShift(
  doctorId: 17,
  specialtyId: 3,
  clinicId: 5,
  weekday: 2,
  startDate: DateTime.utc(2026, 10, 20),
  endDate: DateTime.utc(2026, 12, 15),
  numbers: [
    _n(1, '09:00', '09:20'),
    _n(2, '09:20', '09:40'),
    _n(3, '10:00', '10:30'),
  ],
);

/// Una respuesta mal formada se vuelve el error genérico, con su mensaje.
Matcher get _genericError => isA<ApiException>()
    .having((e) => e.runtimeType, 'es un ApiException liso', ApiException)
    .having((e) => e.message, 'message', kApiGenericMessage);

void main() {
  group('listDoctors (#10)', () {
    test(
      'pide GET /api/medicos sin parámetros si no hay especialidad',
      () async {
        final (repository, adapter) = _ok(200, {'items': <Object>[]});

        await repository.listDoctors();

        expect(adapter.last!.method, 'GET');
        expect(adapter.last!.path, '/api/medicos');
        expect(adapter.last!.queryParameters, isEmpty);
      },
    );

    test('con especialidad manda especialidadId', () async {
      final (repository, adapter) = _ok(200, {'items': <Object>[]});

      await repository.listDoctors(specialtyId: 3);

      expect(adapter.last!.queryParameters, {'especialidadId': 3});
    });

    test('lee los médicos con sus especialidades', () async {
      final (repository, _) = _ok(200, {
        'items': [doctorJson()],
      });

      final doctors = await repository.listDoctors();

      expect(doctors.single.fullName, 'Marta Rodríguez');
      expect(doctors.single.specialties.map((s) => s.id), [1, 3]);
    });

    test('sin médicos devuelve una lista vacía', () async {
      final (repository, _) = _ok(200, {'items': <Object>[]});

      expect(await repository.listDoctors(), isEmpty);
    });

    test('una respuesta sin "items" es el error genérico', () async {
      final (repository, _) = _ok(200, <String, Object>{});

      await expectLater(repository.listDoctors(), throwsA(_genericError));
    });

    test('"items" que no es una lista es el error genérico', () async {
      final (repository, _) = _ok(200, {'items': 'nada'});

      await expectLater(repository.listDoctors(), throwsA(_genericError));
    });

    test('un médico mal formado es el error genérico', () async {
      final (repository, _) = _ok(200, {
        'items': [
          {'id': 1, 'nombre': 'Marta'},
        ],
      });

      await expectLater(repository.listDoctors(), throwsA(_genericError));
    });

    test('un cuerpo nulo es el error genérico', () async {
      final (repository, _) = _ok(200, null);

      await expectLater(repository.listDoctors(), throwsA(_genericError));
    });
  });

  group('getWeeklyShift (#14)', () {
    test('pide GET /api/turnos-semanales/{id}', () async {
      final (repository, adapter) = _ok(200, weeklyShiftJson());

      await repository.getWeeklyShift(120);

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/turnos-semanales/120');
    });

    test('lee la configuración', () async {
      final (repository, _) = _ok(200, weeklyShiftJson());

      final weeklyShift = await repository.getWeeklyShift(120);

      expect(weeklyShift.id, 120);
      expect(weeklyShift.shiftCount, 9);
      expect(weeklyShift.numbers.length, 3);
      expect(weeklyShift.doctor.lastName, 'Rodríguez');
    });

    test(
      'NO_ENCONTRADO es ShiftNotFoundException con el mensaje del servidor',
      () async {
        final (repository, _) = _ok(404, {
          'code': 'NO_ENCONTRADO',
          'message': 'No existe ese turno semanal.',
        });

        await expectLater(
          repository.getWeeklyShift(9999),
          throwsA(
            isA<ShiftNotFoundException>().having(
              (e) => e.message,
              'message',
              'No existe ese turno semanal.',
            ),
          ),
        );
      },
    );

    test('una respuesta sin "id" es el error genérico', () async {
      final (repository, _) = _ok(200, weeklyShiftJson()..remove('id'));

      await expectLater(repository.getWeeklyShift(1), throwsA(_genericError));
    });

    test('una fecha mal escrita es el error genérico', () async {
      final (repository, _) = _ok(
        200,
        weeklyShiftJson()..['fechaFin'] = '15/12/2026',
      );

      await expectLater(repository.getWeeklyShift(1), throwsA(_genericError));
    });
  });

  group('listShifts (#15)', () {
    Map<String, Object> page(List<Object> items, {int total = 9}) => {
      'items': items,
      'page': 0,
      'size': 20,
      'total': total,
    };

    test('pide GET /api/turnos con los parámetros del contrato', () async {
      final (repository, adapter) = _ok(200, page([]));

      await repository.listShifts(
        ShiftFilters(
          doctorId: 17,
          specialtyId: 3,
          weekday: 2,
          fromDate: DateTime.utc(2026, 10, 5),
          toDate: DateTime.utc(2026, 12, 15),
          state: ShiftState.suspended,
          order: ShiftOrder.doctor,
          ascending: false,
          page: 1,
          size: 50,
        ),
      );

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/turnos');
      expect(adapter.last!.queryParameters, {
        'medicoId': 17,
        'especialidadId': 3,
        'diaSemana': 2,
        'fechaDesde': '2026-10-05',
        'fechaHasta': '2026-12-15',
        'estado': 'SUSPENDIDO',
        'orden': 'medico',
        'sentido': 'desc',
        'page': 1,
        'size': 50,
      });
    });

    test(
      'sin filtros manda solo orden, sentido, página (base 0) y tamaño',
      () async {
        final (repository, adapter) = _ok(200, page([]));

        await repository.listShifts(const ShiftFilters());

        expect(adapter.last!.queryParameters, {
          'orden': 'fecha',
          'sentido': 'asc',
          'page': 0,
          'size': 20,
        });
      },
    );

    test(
      'manda exactamente lo que arma ShiftFilters.toQueryParameters',
      () async {
        final filters = ShiftFilters(weekday: 4, page: 2);
        final (repository, adapter) = _ok(200, page([]));

        await repository.listShifts(filters);

        expect(adapter.last!.queryParameters, filters.toQueryParameters());
      },
    );

    test('lee la página y sus turnos', () async {
      final (repository, _) = _ok(200, page([shiftJson()]));

      final result = await repository.listShifts(const ShiftFilters());

      expect(result.total, 9);
      expect(result.size, 20);
      expect(result.items.single.id, 301);
      expect(result.items.single.state, ShiftState.active);
      expect(result.items.single.doctor.lastName, 'Rodríguez');
    });

    test('una página vacía no es un error', () async {
      final (repository, _) = _ok(200, page([], total: 0));

      final result = await repository.listShifts(const ShiftFilters());

      expect(result.items, isEmpty);
      expect(result.total, 0);
    });

    test('VALIDACION es ShiftValidationException', () async {
      final (repository, _) = _ok(400, {
        'code': 'VALIDACION',
        'message': 'La fecha "desde" es posterior a "hasta".',
      });

      await expectLater(
        repository.listShifts(const ShiftFilters()),
        throwsA(isA<ShiftValidationException>()),
      );
    });

    test('un estado desconocido en un turno es el error genérico', () async {
      final (repository, _) = _ok(200, page([shiftJson(estado: 'ARCHIVADO')]));

      await expectLater(
        repository.listShifts(const ShiftFilters()),
        throwsA(_genericError),
      );
    });

    test('una página sin "total" es el error genérico', () async {
      final (repository, _) = _ok(200, page([])..remove('total'));

      await expectLater(
        repository.listShifts(const ShiftFilters()),
        throwsA(_genericError),
      );
    });
  });

  group('createWeeklyShift (#13)', () {
    test('pide POST /api/turnos-semanales con el AltaTurnoDTO', () async {
      final (repository, adapter) = _ok(201, weeklyShiftJson());

      await repository.createWeeklyShift(_newWeeklyShift());

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/turnos-semanales');
      expect(adapter.last!.data, {
        'medicoId': 17,
        'especialidadId': 3,
        'consultorioId': 5,
        'diaSemana': 2,
        'fechaInicio': '2026-10-20',
        'fechaFin': '2026-12-15',
        'numeros': [
          {'numero': 1, 'horaInicio': '09:00', 'horaFin': '09:20'},
          {'numero': 2, 'horaInicio': '09:20', 'horaFin': '09:40'},
          {'numero': 3, 'horaInicio': '10:00', 'horaFin': '10:30'},
        ],
      });
    });

    test('lee el TurnoSemanalDTO de la respuesta 201', () async {
      final (repository, _) = _ok(201, weeklyShiftJson());

      final created = await repository.createWeeklyShift(_newWeeklyShift());

      expect(created.id, 120);
      expect(created.shiftCount, 9);
      expect(created.weekday, 2);
      expect(created.numbers.length, 3);
    });

    group('errores por code', () {
      Future<Object> failWith(
        int status,
        String code, [
        String? message,
      ]) async {
        final (repository, _) = _ok(status, {
          'code': code,
          'message': message ?? 'Mensaje del servidor.',
        });
        try {
          await repository.createWeeklyShift(_newWeeklyShift());
        } catch (e) {
          return e;
        }
        throw StateError('Tenía que fallar');
      }

      test('VALIDACION', () async {
        final error = await failWith(400, 'VALIDACION');
        expect(error, isA<ShiftValidationException>());
        expect(
          (error as ShiftValidationException).message,
          'Mensaje del servidor.',
        );
      });

      test('ESPECIALIDAD_NO_DEL_MEDICO', () async {
        final error = await failWith(400, 'ESPECIALIDAD_NO_DEL_MEDICO');
        expect(error, isA<SpecialtyNotOfDoctorException>());
        expect((error as ApiException).message, 'Mensaje del servidor.');
      });

      test('MEDICO_INACTIVO', () async {
        final error = await failWith(409, 'MEDICO_INACTIVO');
        expect(error, isA<InactiveDoctorException>());
        expect((error as ApiException).message, 'Mensaje del servidor.');
      });

      test('NO_ENCONTRADO', () async {
        final error = await failWith(404, 'NO_ENCONTRADO');
        expect(error, isA<ShiftNotFoundException>());
        expect((error as ApiException).message, 'Mensaje del servidor.');
      });

      test('SOLAPAMIENTO_TURNO pasa el mensaje tal cual', () async {
        const message =
            'No se pudo guardar: los horarios se cruzan con turnos activos '
            'del médico el 20/10/2026 y 27/10/2026 (números 1 y 2). Cambiá los '
            'horarios o las fechas y volvé a guardar.';
        final error = await failWith(409, 'SOLAPAMIENTO_TURNO', message);
        expect(error, isA<OverlappingShiftException>());
        expect((error as ApiException).message, message);
      });

      test('se distingue por el code, no por el texto del mensaje', () async {
        // El texto habla de un cruce, pero el code es otro: no es un cruce.
        final other = await failWith(
          409,
          'OTRO_CODIGO',
          'Los horarios se cruzan con otro turno.',
        );
        expect(other, isNot(isA<OverlappingShiftException>()));
        // Y al revés: el code manda aunque el texto no diga nada de cruces.
        final overlap = await failWith(409, 'SOLAPAMIENTO_TURNO', 'Algo pasó.');
        expect(overlap, isA<OverlappingShiftException>());
      });

      test(
        'un code desconocido cae en ApiException con el mensaje del servidor',
        () async {
          final error = await failWith(409, 'CODIGO_NUEVO');
          expect(error.runtimeType, ApiException);
          expect((error as ApiException).message, 'Mensaje del servidor.');
        },
      );

      test(
        'SIN_PERMISO y ERROR_INTERNO también usan el mensaje del servidor',
        () async {
          final forbidden = await failWith(403, 'SIN_PERMISO');
          expect(forbidden.runtimeType, ApiException);
          expect((forbidden as ApiException).message, 'Mensaje del servidor.');
          final internal = await failWith(500, 'ERROR_INTERNO');
          expect(internal.runtimeType, ApiException);
        },
      );
    });

    test('un error sin cuerpo JSON es el error genérico', () async {
      final (repository, _) = _repository(
        _StubAdapter.raw(502, '<html>Bad gateway</html>'),
      );

      await expectLater(
        repository.createWeeklyShift(_newWeeklyShift()),
        throwsA(_genericError),
      );
    });

    test('un error JSON sin code ni message es el error genérico', () async {
      final (repository, _) = _ok(500, <String, Object>{});

      await expectLater(
        repository.createWeeklyShift(_newWeeklyShift()),
        throwsA(_genericError),
      );
    });

    test('un 201 mal formado es el error genérico', () async {
      final (repository, _) = _ok(201, weeklyShiftJson()..remove('numeros'));

      await expectLater(
        repository.createWeeklyShift(_newWeeklyShift()),
        throwsA(_genericError),
      );
    });
  });

  group('sin conexión', () {
    final calls = <String, Future<Object?> Function(ApiShiftRepository)>{
      'listDoctors': (r) => r.listDoctors(),
      'getWeeklyShift': (r) => r.getWeeklyShift(1),
      'listShifts': (r) => r.listShifts(const ShiftFilters()),
      'createWeeklyShift': (r) => r.createWeeklyShift(_newWeeklyShift()),
    };

    for (final entry in calls.entries) {
      test('${entry.key} da el mismo aviso que el resto de la app', () async {
        final (repository, _) = _repository(_StubAdapter.offline());

        await expectLater(
          entry.value(repository),
          throwsA(
            isA<ApiException>()
                .having((e) => e.runtimeType, 'ApiException liso', ApiException)
                .having((e) => e.message, 'message', kApiNoConnectionMessage),
          ),
        );
      });
    }
  });
}
