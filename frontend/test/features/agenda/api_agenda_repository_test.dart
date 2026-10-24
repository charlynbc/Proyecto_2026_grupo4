import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/repositories/agenda_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/api_agenda_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _item(int numeroId) => {
  'numeroId': numeroId,
  'turnoId': 7,
  'numero': 3,
  'fecha': '2026-11-05',
  'horaInicio': '09:30',
  'horaFin': '09:45:00',
  'medico': {'id': 4, 'nombre': 'Ana', 'apellido': 'Pérez'},
  'especialidad': {'id': 2, 'nombre': 'Cardiología', 'requierePase': true},
  'consultorio': {'id': 1, 'nombre': 'Consultorio 1', 'ubicacion': 'Piso 2'},
};

Map<String, dynamic> _consulta() => _item(11)
  ..remove('numeroId')
  ..remove('turnoId')
  ..addAll({
    'id': 99,
    'estado': 'AGENDADA',
    'paseId': 5,
    'agendadaEn': '2026-10-01T15:00:00Z',
    'canceladaEn': null,
    'motivoCancelacion': null,
  });

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

(ApiAgendaRepository, _Adapter) _repo(int status, Object? body) {
  final adapter = _Adapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (ApiAgendaRepository(dio), adapter);
}

void main() {
  group('disponibilidad', () {
    test('envía los filtros y lee items con fecha y hora locales', () async {
      final (repo, adapter) = _repo(200, {
        'items': [_item(11), _item(12)],
      });
      final result = await repo.listAvailability(
        AvailabilityQuery(
          specialtyId: 2,
          doctorId: 4,
          from: DateTime.utc(2026, 11, 1),
          to: DateTime.utc(2026, 11, 30),
          order: AvailabilityOrder.doctorLastName,
          direction: SortDirection.desc,
        ),
      );

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/disponibilidad');
      expect(adapter.last!.queryParameters, {
        'especialidadId': 2,
        'medicoId': 4,
        'fechaDesde': '2026-11-01',
        'fechaHasta': '2026-11-30',
        'orden': 'apellidoMedico',
        'sentido': 'desc',
      });
      expect(result.map((n) => n.numberId), [11, 12]);
      final n = result.first;
      expect(n.shiftId, 7);
      expect(n.number, 3);
      expect(n.date, DateTime.utc(2026, 11, 5));
      expect(n.timeRange, '09:30 - 09:45');
      expect(n.doctor.lastName, 'Pérez');
      expect(n.specialty.requiresReferral, isTrue);
      expect(n.clinic.location, 'Piso 2');
    });

    test('sin médico ni fechas solo envía la especialidad', () async {
      final (repo, adapter) = _repo(200, {'items': <Object>[]});
      final result = await repo.listAvailability(
        const AvailabilityQuery(specialtyId: 1),
      );
      expect(result, isEmpty);
      final params = adapter.last!.queryParameters;
      expect(params['especialidadId'], 1);
      expect(params.containsKey('medicoId'), isFalse);
      expect(params.containsKey('fechaDesde'), isFalse);
      expect(params.containsKey('fechaHasta'), isFalse);
    });

    test('una respuesta mal formada es un error genérico', () async {
      final (repo, _) = _repo(200, {
        'items': [
          {'numeroId': 'x'},
        ],
      });
      await expectLater(
        repo.listAvailability(const AvailabilityQuery(specialtyId: 1)),
        throwsA(isA<ApiException>()),
      );
    });

    test('un error del servidor llega como ApiException', () async {
      final (repo, _) = _repo(404, {
        'code': 'NO_ENCONTRADO',
        'message': 'No existe la especialidad',
      });
      await expectLater(
        repo.listAvailability(const AvailabilityQuery(specialtyId: 9)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No existe la especialidad',
          ),
        ),
      );
    });
  });

  group('crear consulta', () {
    test('POST /api/consultas con numeroId y paseId nulo', () async {
      final (repo, adapter) = _repo(201, _consulta());
      final appointment = await repo.book(numberId: 11);
      expect(adapter.last!.method, 'POST');
      expect(adapter.last!.path, '/api/consultas');
      expect(adapter.last!.data, {'numeroId': 11, 'paseId': null});
      expect(appointment.id, 99);
      expect(appointment.status, 'AGENDADA');
      expect(appointment.statusLabel, 'Agendada');
      expect(appointment.referralId, 5);
      expect(appointment.bookedAt.isUtc, isTrue);
    });

    test('envía el paseId si se indica', () async {
      final (repo, adapter) = _repo(201, _consulta());
      await repo.book(numberId: 11, referralId: 5);
      expect(adapter.last!.data, {'numeroId': 11, 'paseId': 5});
    });

    const cases = {
      (409, 'NUMERO_NO_DISPONIBLE'): BookingFailure.numberUnavailable,
      (409, 'ANTICIPACION_INVALIDA'): BookingFailure.outsideWindow,
      (409, 'LIMITE_TOTAL'): BookingFailure.totalLimit,
      (409, 'LIMITE_ESPECIALIDAD'): BookingFailure.specialtyLimit,
      (409, 'CONSULTA_SUPERPUESTA'): BookingFailure.overlap,
      (409, 'PASE_NO_VALIDO'): BookingFailure.invalidReferral,
      (400, 'VALIDACION'): BookingFailure.validation,
      (404, 'NO_ENCONTRADO'): BookingFailure.notFound,
      (401, 'NO_AUTENTICADO'): BookingFailure.unauthenticated,
      (403, 'ACCESO_DENEGADO'): BookingFailure.forbidden,
      (500, 'OTRO'): BookingFailure.other,
    };
    cases.forEach((key, failure) {
      test('${key.$2} (${key.$1}) es $failure', () async {
        final (repo, _) = _repo(key.$1, {
          'code': key.$2,
          'message': 'mensaje del servidor',
        });
        await expectLater(
          repo.book(numberId: 11),
          throwsA(
            isA<BookingException>()
                .having((e) => e.failure, 'failure', failure)
                .having((e) => e.message, 'message', 'mensaje del servidor'),
          ),
        );
      });
    });

    test('la disponibilidad queda vieja solo en los casos que corresponde', () {
      for (final failure in BookingFailure.values) {
        expect(
          BookingException(failure).availabilityIsStale,
          {
            BookingFailure.numberUnavailable,
            BookingFailure.outsideWindow,
            BookingFailure.notFound,
          }.contains(failure),
          reason: '$failure',
        );
      }
    });

    test('una consulta mal formada es un error genérico', () async {
      final (repo, _) = _repo(201, {'id': 'x'});
      await expectLater(repo.book(numberId: 11), throwsA(isA<ApiException>()));
    });

    test(
      'un estado desconocido en la consulta creada es un error genérico',
      () async {
        final (repo, _) = _repo(201, _consulta()..['estado'] = 'REPROGRAMADA');
        await expectLater(
          repo.book(numberId: 11),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              kApiGenericMessage,
            ),
          ),
        );
      },
    );
  });

  test('AvailabilityQuery compara por valor', () {
    expect(
      const AvailabilityQuery(specialtyId: 1),
      const AvailabilityQuery(specialtyId: 1),
    );
    expect(
      const AvailabilityQuery(specialtyId: 1),
      isNot(const AvailabilityQuery(specialtyId: 2)),
    );
    expect(
      const AvailabilityQuery(specialtyId: 1, doctorId: 3).withDoctor(null),
      const AvailabilityQuery(specialtyId: 1),
    );
  });
}
