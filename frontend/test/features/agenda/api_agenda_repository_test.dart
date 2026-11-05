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

/// Un pase como lo manda `GET /api/socios/me/pases/disponibles`: Cardiología,
/// la del catálogo de los fakes (id 2).
Map<String, dynamic> _referral(
  int id,
  String expiresOn, {
  String issuedAt = '2026-10-20T14:30:00Z',
}) => {
  'id': id,
  'especialidadDestino': {
    'id': 2,
    'nombre': 'Cardiología',
    'requierePase': true,
  },
  'emitidoEn': issuedAt,
  'venceEl': expiresOn,
};

/// El error genérico de siempre: lo que se ve cuando la respuesta no sirve.
final _genericError = isA<ApiException>().having(
  (e) => e.message,
  'message',
  kApiGenericMessage,
);

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

  group('pases disponibles', () {
    const route = '/api/socios/me/pases/disponibles';

    test('pide GET $route sin parámetros de consulta', () async {
      final (repo, adapter) = _repo(200, <Object>[]);

      await repo.listReferrals();

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, route);
      expect(adapter.last!.queryParameters, isEmpty);
    });

    test('lee una lista de dos pases con todos sus campos', () async {
      final (repo, _) = _repo(200, [
        _referral(77, '2026-11-19'),
        _referral(78, '2026-12-01', issuedAt: '2026-10-22T11:30:00-03:00'),
      ]);

      final referrals = await repo.listReferrals();

      expect(referrals, hasLength(2));
      expect(referrals[0].id, 77);
      expect(referrals[0].specialty.id, 2);
      expect(referrals[0].specialty.name, 'Cardiología');
      expect(referrals[0].issuedAt, DateTime.utc(2026, 10, 20, 14, 30));
      expect(referrals[0].expiresOn, DateTime.utc(2026, 11, 19));
      expect(referrals[1].id, 78);
      expect(referrals[1].issuedAt, DateTime.utc(2026, 10, 22, 14, 30));
      expect(referrals[1].expiresOn, DateTime.utc(2026, 12, 1));
    });

    test('una lista vacía da una lista vacía, no un error', () async {
      final (repo, _) = _repo(200, <Object>[]);

      expect(await repo.listReferrals(), isEmpty);
    });

    test('un cuerpo que no es una lista es el error genérico', () async {
      final (repo, _) = _repo(200, {'items': <Object>[]});

      await expectLater(repo.listReferrals(), throwsA(_genericError));
    });

    test(
      'un elemento con venceEl en otro formato es el error genérico',
      () async {
        final (repo, _) = _repo(200, [_referral(77, '19/11/2026')]);

        await expectLater(repo.listReferrals(), throwsA(_genericError));
      },
    );

    test('un elemento sin id es el error genérico', () async {
      final (repo, _) = _repo(200, [_referral(77, '2026-11-19')..remove('id')]);

      await expectLater(repo.listReferrals(), throwsA(_genericError));
    });

    test('un 401 TOKEN_INVALIDO sale con el mensaje del servidor', () async {
      final (repo, _) = _repo(401, {
        'code': 'TOKEN_INVALIDO',
        'message': 'La sesión no es válida',
      });

      await expectLater(
        repo.listReferrals(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'La sesión no es válida',
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

  group('médicos', () {
    // El ejemplo del contrato para el socio (#10): lista sin envoltorio.
    final memberBody = [
      {
        'id': 17,
        'nombre': 'Marta',
        'apellido': 'Rodríguez',
        'especialidades': [
          {'id': 1, 'nombre': 'Medicina General'},
          {'id': 3, 'nombre': 'Cardiología'},
        ],
      },
    ];

    test('pide GET /api/medicos y lee la lista sin envoltorio', () async {
      final (repo, adapter) = _repo(200, memberBody);

      final doctors = await repo.listDoctors();

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.path, '/api/medicos');
      expect(adapter.last!.queryParameters, isEmpty);
      expect(doctors, hasLength(1));
      expect(doctors.single.id, 17);
      expect(doctors.single.fullName, 'Marta Rodríguez');
      expect(doctors.single.specialties.map((s) => s.id), [1, 3]);
      expect(doctors.single.specialties.map((s) => s.name), [
        'Medicina General',
        'Cardiología',
      ]);
    });

    test('con especialidadId lo manda como parámetro', () async {
      final (repo, adapter) = _repo(200, memberBody);

      await repo.listDoctors(specialtyId: 3);

      expect(adapter.last!.queryParameters, {'especialidadId': 3});
    });

    test('una lista vacía da una lista vacía', () async {
      final (repo, _) = _repo(200, <Object>[]);

      expect(await repo.listDoctors(), isEmpty);
    });

    test('tolera el envoltorio items', () async {
      final (repo, _) = _repo(200, {'items': memberBody});

      expect((await repo.listDoctors()).map((d) => d.id), [17]);
    });

    test('una respuesta mal formada es el error genérico', () async {
      for (final body in <Object?>[
        'hola',
        [
          {'id': 17},
        ],
      ]) {
        final (repo, _) = _repo(200, body);
        await expectLater(repo.listDoctors(), throwsA(_genericError));
      }
    });

    test('un error del servidor llega como ApiException con su mensaje', () async {
      final (repo, _) = _repo(403, {
        'code': 'ACCESO_DENEGADO',
        'message': 'No tenés permiso para ver esta información.',
      });

      await expectLater(
        repo.listDoctors(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'No tenés permiso para ver esta información.',
          ),
        ),
      );
    });
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
