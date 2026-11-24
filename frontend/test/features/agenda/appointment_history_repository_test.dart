import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/repositories/api_appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _appointment() => {
  'id': 9001,
  'estado': 'NO_ATENDIDA',
  'fecha': '2026-10-20',
  'numero': 2,
  'horaInicio': '09:20',
  'horaFin': '09:40',
  'medico': {'id': 17, 'nombre': 'Marta', 'apellido': 'Rodríguez'},
  'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  'consultorio': {'id': 5, 'nombre': 'Consultorio 5', 'ubicacion': 'Piso 2'},
  'paseId': null,
  'agendadaEn': '2026-10-20T10:12:45-03:00',
  'canceladaEn': null,
  'motivoCancelacion': null,
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

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

(ApiAppointmentHistoryRepository, _Adapter) _repository(
  int status,
  Object? body,
) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiAppointmentHistoryRepository(dio), adapter);
}

void main() {
  test(
    'consulta el listado real con filtros y parsea la respuesta paginada',
    () async {
      final (repository, adapter) = _repository(200, {
        'items': [_appointment()],
        'page': 1,
        'size': 10,
        'total': 23,
      });

      final result = await repository.list(
        AppointmentHistoryQuery(
          status: 'NO_ATENDIDA',
          from: DateTime.utc(2026, 10, 1),
          to: DateTime.utc(2026, 10, 31),
          specialtyId: 3,
          doctorId: 17,
          order: AppointmentHistoryOrder.specialty,
          direction: AppointmentHistoryDirection.ascending,
          page: 1,
          size: 10,
        ),
      );

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/consultas');
      expect(adapter.last!.queryParameters, {
        'estado': 'NO_ATENDIDA',
        'fechaDesde': '2026-10-01',
        'fechaHasta': '2026-10-31',
        'especialidadId': 3,
        'medicoId': 17,
        'orden': 'especialidad',
        'sentido': 'asc',
        'page': 1,
        'size': 10,
      });
      expect(result.total, 23);
      expect(result.hasPrevious, isTrue);
      expect(result.hasNext, isTrue);
      expect(result.items.single.status, 'NO_ATENDIDA');
      expect(result.items.single.timeRange, '09:20 - 09:40');
      expect(result.items.single.date, DateTime.utc(2026, 10, 20));
      expect(
        result.items.single.bookedAt,
        DateTime.utc(2026, 10, 20, 13, 12, 45),
      );
    },
  );

  test('consulta el detalle por la ruta centralizada', () async {
    final (repository, adapter) = _repository(200, _appointment());

    final result = await repository.get(9001);

    expect(adapter.last!.method, 'GET');
    expect(adapter.last!.path, '/api/consultas/9001');
    expect(result.id, 9001);
    expect(result.statusLabel, 'No atendida');
  });

  test('no interpreta las fechas ni horas locales como UTC', () async {
    final (repository, _) = _repository(200, {
      'items': [_appointment()],
      'page': 0,
      'size': 20,
      'total': 1,
    });

    final item = (await repository.list(const AppointmentHistoryQuery()))
        .items
        .single;

    expect(item.date, DateTime.utc(2026, 10, 20));
    expect(item.timeRange, '09:20 - 09:40');
  });

  for (final (status, code, failure) in [
    (401, 'NO_AUTENTICADO', AppointmentHistoryFailure.unauthenticated),
    (403, 'ACCESO_DENEGADO', AppointmentHistoryFailure.forbidden),
    (404, 'NO_ENCONTRADO', AppointmentHistoryFailure.notFound),
  ]) {
    test('mapea $status/$code', () async {
      final (repository, _) = _repository(status, {
        'code': code,
        'message': 'respuesta contractual',
      });

      await expectLater(
        repository.get(9001),
        throwsA(
          isA<AppointmentHistoryException>()
              .having((e) => e.failure, 'failure', failure)
              .having((e) => e.message, 'message', 'respuesta contractual'),
        ),
      );
    });
  }

  test('un JSON de historial mal formado genera error explícito', () async {
    final (repository, _) = _repository(200, {
      'items': [
        {'id': 'incorrecto'},
      ],
      'page': 0,
      'size': 20,
      'total': 1,
    });

    await expectLater(
      repository.list(const AppointmentHistoryQuery()),
      throwsA(isA<ApiException>()),
    );
  });

  test('el identificador del detalle debe ser positivo', () async {
    final (repository, adapter) = _repository(200, _appointment());

    await expectLater(
      repository.get(0),
      throwsA(
        isA<AppointmentHistoryException>().having(
          (e) => e.failure,
          'failure',
          AppointmentHistoryFailure.notFound,
        ),
      ),
    );
    expect(adapter.last, isNull);
  });

  test('un estado desconocido en el listado es el error genérico', () async {
    final (repository, _) = _repository(200, {
      'items': [_appointment()..['estado'] = 'REPROGRAMADA'],
      'page': 0,
      'size': 20,
      'total': 1,
    });

    await expectLater(
      repository.list(const AppointmentHistoryQuery()),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          kApiGenericMessage,
        ),
      ),
    );
  });

  test('un estado desconocido en el detalle es el error genérico', () async {
    final (repository, _) = _repository(
      200,
      _appointment()..['estado'] = 'REPROGRAMADA',
    );

    await expectLater(
      repository.get(9001),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          kApiGenericMessage,
        ),
      ),
    );
  });

  group('cancelable', () {
    test('la lista conserva el campo de cada consulta', () async {
      final (repository, _) = _repository(200, {
        'items': [
          {..._appointment(), 'id': 9001, 'cancelable': true},
          {..._appointment(), 'id': 9002, 'cancelable': false},
          {..._appointment(), 'id': 9003},
        ],
        'page': 0,
        'size': 20,
        'total': 3,
      });

      final items = (await repository.list(const AppointmentHistoryQuery()))
          .items;

      expect([for (final a in items) a.cancelable], [true, false, null]);
    });

    test('el detalle conserva el campo', () async {
      final (conTrue, _) = _repository(200, {
        ..._appointment(),
        'cancelable': true,
      });
      final (conFalse, _) = _repository(200, {
        ..._appointment(),
        'cancelable': false,
      });
      final (sinCampo, _) = _repository(200, _appointment());

      expect((await conTrue.get(9001)).cancelable, isTrue);
      expect((await conFalse.get(9001)).cancelable, isFalse);
      expect((await sinCampo.get(9001)).cancelable, isNull);
    });

    test('un valor que no es booleano da el error generico', () async {
      final (lista, _) = _repository(200, {
        'items': [
          {..._appointment(), 'cancelable': 'si'},
        ],
        'page': 0,
        'size': 20,
        'total': 1,
      });
      final (detalle, _) = _repository(200, {
        ..._appointment(),
        'cancelable': 1,
      });

      await expectLater(
        lista.list(const AppointmentHistoryQuery()),
        throwsA(isA<ApiException>()),
      );
      await expectLater(detalle.get(9001), throwsA(isA<ApiException>()));
    });
  });
}
