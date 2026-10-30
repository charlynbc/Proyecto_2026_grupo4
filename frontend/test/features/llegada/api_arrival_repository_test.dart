import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/llegada/repositories/api_arrival_repository.dart';
import 'package:agenda_medica/features/llegada/repositories/arrival_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptador de dio que anota el pedido y responde con lo indicado.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);

  final int status;
  final Object? body;
  RequestOptions? last;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    calls++;
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

(ApiArrivalRepository, _StubAdapter) _repository(int status, Object? body) {
  final adapter = _StubAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiArrivalRepository(dio), adapter);
}

const _anaAppointment = {
  'id': 184,
  'estado': 'AGENDADA',
  'fecha': '2026-10-22',
  'numero': 2,
  'horaInicio': '09:00',
  'horaFin': '09:20',
  'medico': {'id': 41, 'nombre': 'Alejandro', 'apellido': 'Rivas'},
  'especialidad': {
    'id': 1,
    'nombre': 'Medicina general',
    'requierePase': false,
  },
  'consultorio': {
    'id': 1,
    'nombre': 'Consultorio 1',
    'ubicacion': 'Planta baja, sector 1',
  },
  'paseId': null,
  'agendadaEn': '2026-10-15T10:00:00-03:00',
  'canceladaEn': null,
  'motivoCancelacion': null,
};

Map<String, Object?> _arrival() => {
  'id': 7,
  'socio': {'ci': '90000046', 'nombre': 'Ana', 'apellido': 'Fernández'},
  'fecha': '2026-10-22',
  'registradaEn': '2026-10-22T08:47:00-03:00',
  'registradaPor': {'id': 46, 'nombre': 'Mariana', 'apellido': 'Ferreira'},
};

Map<String, String> _error(String code) => {
  'code': code,
  'message': 'Mensaje del servidor para $code',
};

void main() {
  group('consultas de hoy', () {
    test('pide la ruta del contrato con la CI y lee los items', () async {
      final (repository, adapter) = _repository(200, {
        'items': [_anaAppointment],
      });

      final appointments = await repository.listTodayAppointments('90000046');

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/avisos-llegada/consultas-hoy');
      expect(adapter.last!.queryParameters, {'ci': '90000046'});
      expect(appointments, hasLength(1));
      expect(appointments.single.id, 184);
      expect(appointments.single.doctor.lastName, 'Rivas');
      expect(appointments.single.clinic.name, 'Consultorio 1');
    });

    test('manda la CI solo con digitos', () async {
      final (repository, adapter) = _repository(200, {'items': <Object>[]});

      await repository.listTodayAppointments('9.000.004-6');

      expect(adapter.last!.queryParameters, {'ci': '90000046'});
    });

    test('404 NO_ENCONTRADO es socio inexistente', () async {
      final (repository, _) = _repository(404, _error('NO_ENCONTRADO'));

      await expectLater(
        repository.listTodayAppointments('90000046'),
        throwsA(isA<MemberNotFoundException>()),
      );
    });
  });

  group('registrar llegada', () {
    test('el body es exactamente la CI solo con digitos', () async {
      final (repository, adapter) = _repository(201, _arrival());

      await repository.registerArrival('9.000.004-6');

      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/avisos-llegada');
      expect(adapter.last!.data, {'ci': '90000046'});
    });

    test('201 es un aviso creado ahora', () async {
      final (repository, _) = _repository(201, _arrival());

      final result = await repository.registerArrival('90000046');

      expect(result.created, isTrue);
      expect(result.arrival.memberFirstName, 'Ana');
      expect(result.arrival.registeredByFirstName, 'Mariana');
      expect(result.arrival.registeredByLastName, 'Ferreira');
      expect(
        result.arrival.registeredAt.toUtc(),
        DateTime.utc(2026, 10, 22, 11, 47),
      );
    });

    test('200 es un aviso que ya existia', () async {
      final (repository, _) = _repository(200, _arrival());

      final result = await repository.registerArrival('90000046');

      expect(result.created, isFalse);
    });

    for (final code in ['CONFLICTO_INTERES', 'CONFLICTO_DE_INTERES']) {
      test('403 $code es conflicto de interes', () async {
        final (repository, _) = _repository(403, _error(code));

        await expectLater(
          repository.registerArrival('90000046'),
          throwsA(isA<ConflictOfInterestException>()),
        );
      });
    }

    for (final code in ['SIN_CONSULTAS_AGENDADAS', 'SIN_CONSULTAS_HOY']) {
      test('409 $code es sin consultas hoy', () async {
        final (repository, _) = _repository(409, _error(code));

        await expectLater(
          repository.registerArrival('90000046'),
          throwsA(isA<NoAppointmentsTodayException>()),
        );
      });
    }
  });
}
