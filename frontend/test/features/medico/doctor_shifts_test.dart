import 'dart:convert';
import 'dart:typed_data';

import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/medico/repositories/api_doctor_shift_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_shift_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_shifts_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

(ApiDoctorShiftRepository, _StubAdapter) _api(int status, Object? body) {
  final adapter = _StubAdapter(status, body);
  return (
    ApiDoctorShiftRepository(Dio()..httpClientAdapter = adapter),
    adapter,
  );
}

const _shiftJson = {
  'id': 7,
  'fecha': '2026-03-09',
  'horaInicio': '09:00:00',
  'horaFin': '10:00:00',
  'especialidad': {
    'id': 1,
    'nombre': 'Medicina General',
    'requierePase': false,
  },
  'consultorio': {'id': 2, 'nombre': 'Consultorio 1', 'ubicacion': 'PB'},
  'estado': 'ACTIVO',
  'cantidadNumeros': 3,
  'cantidadReservados': 1,
};

/// Repositorio manual: devuelve lo que el test deje en [numbers] y cuenta las
/// consultas, para comprobar el sondeo sin tocar el servidor.
class _ScriptedRepository implements DoctorShiftRepository {
  List<DoctorShift> shifts = [_shift(reserved: 0)];
  List<DoctorShiftNumber> numbers = [_free(1), _free(2)];
  Object? failure;
  int shiftCalls = 0;
  int numberCalls = 0;
  bool? lastArrived;
  DoctorNumbersOrder? lastOrder;
  bool? lastAscending;

  @override
  Future<List<DoctorShift>> listShifts(String date) async {
    shiftCalls++;
    if (failure != null) throw failure!;
    return shifts;
  }

  @override
  Future<DoctorShiftNumbers> listNumbers(
    int shiftId, {
    bool? arrived,
    DoctorNumbersOrder order = DoctorNumbersOrder.time,
    bool ascending = true,
  }) async {
    numberCalls++;
    lastArrived = arrived;
    lastOrder = order;
    lastAscending = ascending;
    if (failure != null) throw failure!;
    final items = arrived == null
        ? numbers
        : [
            for (final n in numbers)
              if (n.isReserved && n.hasArrived == arrived) n,
          ];
    return DoctorShiftNumbers(shiftId: shiftId, items: items);
  }
}

DoctorShift _shift({required int reserved}) => DoctorShift(
  id: 7,
  date: '2026-03-09',
  startTime: '09:00',
  endTime: '10:00',
  specialtyName: 'Medicina General',
  clinicName: 'Consultorio 1',
  status: 'ACTIVO',
  numbersCount: 2,
  reservedCount: reserved,
);

DoctorShiftNumber _free(int n) => DoctorShiftNumber(
  numberId: n,
  number: n,
  startTime: '09:${(n - 1) * 20}'.padRight(5, '0'),
  endTime: '09:${n * 20}'.padRight(5, '0'),
);

DoctorShiftNumber _reserved(int n, {DateTime? arrivedAt}) => DoctorShiftNumber(
  numberId: n,
  number: n,
  startTime: '09:00',
  endTime: '09:20',
  appointmentId: 100 + n,
  appointmentStatus: 'AGENDADA',
  patient: const DoctorPatient(ci: '12345678', name: 'Ana', lastName: 'Pérez'),
  arrivedAt: arrivedAt,
);

Future<void> _pump(WidgetTester tester, _ScriptedRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith((ref) async => repository),
        doctorPollIntervalProvider.overrideWithValue(
          const Duration(seconds: 3),
        ),
      ],
      child: const MaterialApp(home: DoctorShiftsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('contrato con GET /api/medico/turnos', () {
    test('lista turnos con fecha y lee la respuesta real', () async {
      final (repository, adapter) = _api(200, {
        'items': [_shiftJson],
      });

      final shifts = await repository.listShifts('2026-03-09');

      expect(adapter.last!.path, '/api/medico/turnos');
      expect(adapter.last!.queryParameters, {'fecha': '2026-03-09'});
      expect(shifts.single.id, 7);
      expect(shifts.single.startTime, '09:00');
      expect(shifts.single.specialtyName, 'Medicina General');
      expect(shifts.single.reservedCount, 1);
    });

    test('lee números reservados y libres, con filtro y orden', () async {
      final (repository, adapter) = _api(200, {
        'turno': {'id': 7, 'fecha': '2026-03-09', 'estado': 'ACTIVO'},
        'items': [
          {
            'numeroId': 1,
            'numero': 1,
            'horaInicio': '09:00',
            'horaFin': '09:20',
            'consulta': {
              'id': 5,
              'estado': 'AGENDADA',
              'paciente': {
                'ci': '12345678',
                'nombre': 'Ana',
                'apellido': 'Pérez',
              },
              'llegadaEn': '2026-03-09T12:05:00Z',
            },
            'disponible': false,
          },
          {
            'numeroId': 2,
            'numero': 2,
            'horaInicio': '09:20',
            'horaFin': '09:40',
            'consulta': null,
            'disponible': true,
          },
        ],
      });

      final result = await repository.listNumbers(
        7,
        arrived: true,
        order: DoctorNumbersOrder.arrival,
        ascending: false,
      );

      expect(adapter.last!.path, '/api/medico/turnos/7/numeros');
      expect(adapter.last!.queryParameters, {
        'llegada': true,
        'orden': 'horaLlegada',
        'sentido': 'desc',
      });
      expect(result.items.first.patient!.ci, '12345678');
      expect(result.items.first.arrivedAt, DateTime.utc(2026, 3, 9, 12, 5));
      expect(result.items.last.isReserved, isFalse);
    });

    test('sin filtro no envía llegada', () async {
      final (repository, adapter) = _api(200, {
        'turno': {'id': 7},
        'items': <Object>[],
      });

      await repository.listNumbers(7);

      expect(adapter.last!.queryParameters.containsKey('llegada'), isFalse);
      expect(adapter.last!.queryParameters['sentido'], 'asc');
    });

    test(
      'un rechazo del servidor y una respuesta mal formada fallan',
      () async {
        final (denied, _) = _api(403, {
          'code': 'ACCESO_DENEGADO',
          'message': 'No tenés permiso',
        });
        await expectLater(denied.listShifts('2026-03-09'), throwsA(anything));

        final (malformed, _) = _api(200, {'items': 'nada'});
        await expectLater(
          malformed.listShifts('2026-03-09'),
          throwsA(anything),
        );
      },
    );
  });

  group('pantalla del médico', () {
    testWidgets('sin turnos avisa y no inventa datos', (tester) async {
      final repository = _ScriptedRepository()..shifts = [];
      await _pump(tester, repository);

      expect(find.byKey(const Key('doctor-no-shifts')), findsOneWidget);
    });

    testWidgets('muestra números, pacientes, sin reserva y llegada', (
      tester,
    ) async {
      final repository = _ScriptedRepository()
        ..numbers = [
          _reserved(1, arrivedAt: DateTime.utc(2026, 3, 9, 12, 5)),
          _free(2),
        ];
      await _pump(tester, repository);

      await tester.tap(find.byKey(const Key('doctor-shift-7')));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Ana Pérez · CI 12345678'), findsOneWidget);
      expect(find.textContaining('Llegó a las'), findsOneWidget);
      expect(find.text('Sin reserva'), findsOneWidget);
    });

    testWidgets('el filtro y el orden se envían al servidor', (tester) async {
      final repository = _ScriptedRepository()
        ..numbers = [
          _reserved(1, arrivedAt: DateTime.utc(2026, 3, 9, 12, 5)),
          _reserved(2),
        ];
      await _pump(tester, repository);
      await tester.tap(find.byKey(const Key('doctor-shift-7')));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('arrived-filter-yes')));
      await tester.pump();
      await tester.pump();
      expect(repository.lastArrived, isTrue);
      expect(find.byKey(const Key('doctor-number-1')), findsOneWidget);
      expect(find.byKey(const Key('doctor-number-2')), findsNothing);

      await tester.tap(find.text('Hora de llegada'));
      await tester.pump();
      await tester.pump();
      expect(repository.lastOrder, DoctorNumbersOrder.arrival);
      expect(repository.lastArrived, isTrue);

      await tester.tap(find.byKey(const Key('doctor-direction')));
      await tester.pump();
      await tester.pump();
      expect(repository.lastAscending, isFalse);
    });

    testWidgets('se actualiza solo cuando cambia el servidor', (tester) async {
      final repository = _ScriptedRepository();
      await _pump(tester, repository);
      await tester.tap(find.byKey(const Key('doctor-shift-7')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Sin reserva'), findsNWidgets(2));
      expect(find.textContaining('0 de 2 números'), findsOneWidget);

      // Otro cliente reserva y registra la llegada: nadie toca la pantalla.
      repository
        ..shifts = [_shift(reserved: 1)]
        ..numbers = [
          _reserved(1, arrivedAt: DateTime.utc(2026, 3, 9, 12, 5)),
          _free(2),
        ];
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Ana Pérez · CI 12345678'), findsOneWidget);
      expect(find.textContaining('Llegó a las'), findsOneWidget);
      expect(find.textContaining('1 de 2 números'), findsOneWidget);
    });

    testWidgets('no solapa consultas y se detiene al salir', (tester) async {
      final repository = _ScriptedRepository();
      await _pump(tester, repository);
      final antes = repository.shiftCalls;

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(repository.shiftCalls, antes + 1);

      await tester.pumpWidget(const SizedBox());
      final alSalir = repository.shiftCalls;
      await tester.pump(const Duration(seconds: 9));
      expect(repository.shiftCalls, alSalir);
    });

    testWidgets('con la pantalla oculta no consulta y al volver actualiza', (
      tester,
    ) async {
      final repository = _ScriptedRepository();
      await _pump(tester, repository);
      final antes = repository.shiftCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(seconds: 9));
      expect(repository.shiftCalls, antes);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      expect(repository.shiftCalls, antes + 1);
    });

    testWidgets('un error al actualizar conserva los datos y reintenta', (
      tester,
    ) async {
      final repository = _ScriptedRepository();
      await _pump(tester, repository);
      await tester.tap(find.byKey(const Key('doctor-shift-7')));
      await tester.pump();
      await tester.pump();

      repository.failure = Exception('sin red');
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('doctor-refresh-error')), findsOneWidget);
      expect(find.byKey(const Key('doctor-number-1')), findsOneWidget);

      repository.failure = null;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('doctor-refresh-error')), findsNothing);
    });

    testWidgets('un error de carga ofrece reintentar', (tester) async {
      final repository = _ScriptedRepository()..failure = Exception('x');
      await _pump(tester, repository);

      expect(find.byKey(const Key('doctor-error')), findsOneWidget);
      repository.failure = null;
      await tester.tap(find.byKey(const Key('doctor-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('doctor-shift-7')), findsOneWidget);
    });
  });
}
