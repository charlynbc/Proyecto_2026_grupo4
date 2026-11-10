import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/medico/models/doctor_cancellation_result.dart';
import 'package:agenda_medica/features/medico/models/doctor_shift_cancellation_result.dart';
import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/medico/providers/doctor_cancellation_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_shift_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_result_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';

const _ana = DoctorPatient(ci: '1.111.111-1', name: 'Ana', lastName: 'Pérez');
const _luis = DoctorPatient(ci: '2.222.222-2', name: 'Luis', lastName: 'Gómez');
const _emptyReason = 'Escribí el motivo de la cancelación.';
const _cancelled = 'Consulta cancelada. Se le avisará al socio.';
const _cancelledWithPass =
    'Consulta cancelada. Se le avisará al socio. El pase volvió a estar disponible.';
const _outsideWindow =
    'Ya no se puede cancelar: faltan menos de 2 horas para la hora del número. '
    'Si es un imprevisto, coordinalo con la administración.';
const _notScheduled =
    'Esta consulta ya no está agendada, así que no se puede cancelar. '
    'Se actualizó la lista.';
const _notFound =
    'No encontramos esta consulta entre las tuyas. Se actualizó la lista.';
const _conflict =
    'No podés cancelar una consulta en la que vos sos el socio. '
    'Pedile a otra persona que lo haga.';
const _generic = 'No se pudo completar la cancelación.';
const _luisBody =
    'Se cancela la consulta de Luis Gómez. Se le avisa al socio por '
    'notificación, con el motivo que escribas.';

class _Agenda implements DoctorShiftRepository {
  int shiftCalls = 0;
  int numberCalls = 0;

  @override
  Future<List<DoctorShift>> listShifts(String date) async {
    shiftCalls++;
    return [
      DoctorShift(
        id: 7,
        date: date,
        startTime: '09:00',
        endTime: '10:40',
        specialtyName: 'Medicina General',
        clinicName: 'Consultorio 1',
        status: 'ACTIVO',
        numbersCount: 5,
        reservedCount: 4,
      ),
    ];
  }

  @override
  Future<DoctorShiftNumbers> listNumbers(
    int shiftId, {
    bool? arrived,
    DoctorNumbersOrder order = DoctorNumbersOrder.time,
    bool ascending = true,
  }) async {
    numberCalls++;
    return DoctorShiftNumbers(shiftId: shiftId, items: _numbers);
  }
}

class _Cancel implements DoctorCancellationRepository {
  @override
  Future<DoctorShiftCancellationResult> cancelShift(
    int shiftId,
    String reason,
  ) => throw UnimplementedError();
  final calls = <(int, String)>[];
  Completer<void>? gate;
  final List<Object> errors = [];
  bool referralReturned = false;

  @override
  Future<DoctorCancellationResult> cancelAppointment(
    int appointmentId,
    String reason,
  ) async {
    calls.add((appointmentId, reason));
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return DoctorCancellationResult(
      appointmentId: appointmentId,
      status: 'CANCELADA_INSTITUCION',
      cancelledAt: DateTime.utc(2026, 10, 30, 12, 3, 10),
      referralReturned: referralReturned,
    );
  }
}

final _numbers = <DoctorShiftNumber>[
  DoctorShiftNumber(
    numberId: 1,
    number: 1,
    startTime: '09:00',
    endTime: '09:20',
    appointmentId: 10,
    appointmentStatus: 'AGENDADA',
    patient: _ana,
    arrivedAt: DateTime.utc(2026, 10, 30, 11, 50),
  ),
  const DoctorShiftNumber(
    numberId: 2,
    number: 2,
    startTime: '09:20',
    endTime: '09:40',
    appointmentId: 11,
    appointmentStatus: 'AGENDADA',
    patient: _luis,
  ),
  const DoctorShiftNumber(
    numberId: 3,
    number: 3,
    startTime: '09:40',
    endTime: '10:00',
    appointmentId: 12,
    appointmentStatus: 'ATENDIDA',
    patient: _ana,
  ),
  const DoctorShiftNumber(
    numberId: 4,
    number: 4,
    startTime: '10:00',
    endTime: '10:20',
    appointmentId: 13,
    appointmentStatus: 'NO_SE_PRESENTO',
    patient: _luis,
  ),
  const DoctorShiftNumber(
    numberId: 5,
    number: 5,
    startTime: '10:20',
    endTime: '10:40',
  ),
];

Future<void> _pump(
  WidgetTester tester,
  _Agenda agenda,
  _Cancel cancel, {
  Size size = const Size(800, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/medico/turnos',
    routes: [
      GoRoute(
        path: '/medico/turnos',
        builder: (_, _) => const DoctorShiftsScreen(),
      ),
      GoRoute(
        path: kDoctorResultPath,
        builder: (_, state) => Text('Resultado: ${state.uri}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith((ref) async => agenda),
        doctorCancellationRepositoryProvider.overrideWith(
          (ref) async => cancel,
        ),
        doctorPollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  final shift = find.byKey(const Key('doctor-shift-7'));
  await tester.ensureVisible(shift);
  await tester.tap(shift);
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, int appointmentId) async {
  final button = find.byKey(Key('cancel-appointment-$appointmentId'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _typeReason(WidgetTester tester, String reason) async {
  await tester.enterText(find.byKey(const Key('cancel-reason-field')), reason);
  await tester.pump();
}

ButtonStyleButton _button(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(Key(key)));

void main() {
  testWidgets('el botón está solo en las consultas agendadas', (tester) async {
    await _pump(tester, _Agenda(), _Cancel());

    expect(find.byKey(const Key('cancel-appointment-10')), findsOneWidget);
    expect(find.byKey(const Key('cancel-appointment-11')), findsOneWidget);
    expect(find.byKey(const Key('cancel-appointment-12')), findsNothing);
    expect(find.byKey(const Key('cancel-appointment-13')), findsNothing);
    expect(find.byKey(const Key('cancel-appointment-5')), findsNothing);
  });

  testWidgets('cancelar la 10 abre el diálogo y no el resultado', (
    tester,
  ) async {
    await _pump(tester, _Agenda(), _Cancel());

    await _open(tester, 10);

    expect(find.text('¿Cancelar la consulta?'), findsOneWidget);
    expect(find.textContaining('Resultado:'), findsNothing);
  });

  testWidgets('el diálogo de Luis dice el nombre y Volver no llama', (
    tester,
  ) async {
    final cancel = _Cancel();
    await _pump(tester, _Agenda(), cancel);
    await _open(tester, 11);

    expect(find.text('¿Cancelar la consulta?'), findsOneWidget);
    expect(find.text(_luisBody), findsOneWidget);
    expect(find.byKey(const Key('dismiss-cancel-dialog')), findsOneWidget);
    expect(find.byKey(const Key('confirm-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dismiss-cancel-dialog')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(cancel.calls, isEmpty);
  });

  testWidgets('confirmar vacío no llama y lo dice bajo el campo', (
    tester,
  ) async {
    final cancel = _Cancel();
    await _pump(tester, _Agenda(), cancel);
    await _open(tester, 11);

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pump();

    expect(find.text(_emptyReason), findsOneWidget);
    expect(cancel.calls, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('un motivo en blanco tampoco llama', (tester) async {
    final cancel = _Cancel();
    await _pump(tester, _Agenda(), cancel);
    await _open(tester, 11);
    await _typeReason(tester, '   ');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pump();

    expect(find.text(_emptyReason), findsOneWidget);
    expect(cancel.calls, isEmpty);
  });

  testWidgets('con motivo cierra, avisa y vuelve a pedir la agenda', (
    tester,
  ) async {
    final agenda = _Agenda();
    final cancel = _Cancel();
    await _pump(tester, agenda, cancel);
    final shiftsBefore = agenda.shiftCalls;
    final numbersBefore = agenda.numberCalls;
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(cancel.calls, [(11, 'Imprevisto de guardia')]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(_cancelled), findsOneWidget);
    expect(agenda.shiftCalls, shiftsBefore + 1);
    expect(agenda.numberCalls, numbersBefore + 1);
  });

  testWidgets('si el pase volvió el aviso lo dice', (tester) async {
    final cancel = _Cancel()..referralReturned = true;
    await _pump(tester, _Agenda(), cancel);
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(find.text(_cancelledWithPass), findsOneWidget);
  });

  testWidgets('mientras envía no se cierra ni se manda dos veces', (
    tester,
  ) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final cancel = _Cancel()..gate = gate;
    await _pump(tester, _Agenda(), cancel);
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pump();

    expect(cancel.calls, hasLength(1));
    expect(_button(tester, 'confirm-cancel').onPressed, isNull);
    expect(_button(tester, 'dismiss-cancel-dialog').onPressed, isNull);

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pump();
    expect(cancel.calls, hasLength(1));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.tapAt(const Offset(8, 8));
    await tester.pump();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(cancel.calls, hasLength(1));
  });

  testWidgets('fuera de plazo sigue abierto y no recarga', (tester) async {
    final agenda = _Agenda();
    final cancel = _Cancel()
      ..errors.add(
        const DoctorCancellationException(
          DoctorCancellationFailure.outsideWindow,
          _outsideWindow,
        ),
      );
    await _pump(tester, agenda, cancel);
    final shiftsBefore = agenda.shiftCalls;
    final numbersBefore = agenda.numberCalls;
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byKey(const Key('cancel-dialog-error')), findsOneWidget);
    expect(find.text(_outsideWindow), findsOneWidget);
    expect(agenda.shiftCalls, shiftsBefore);
    expect(agenda.numberCalls, numbersBefore);
  });

  testWidgets('si ya no está agendada muestra el texto y recarga', (
    tester,
  ) async {
    final agenda = _Agenda();
    final cancel = _Cancel()
      ..errors.add(
        const DoctorCancellationException(
          DoctorCancellationFailure.notScheduled,
          _notScheduled,
        ),
      );
    await _pump(tester, agenda, cancel);
    final shiftsBefore = agenda.shiftCalls;
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(find.text(_notScheduled), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(agenda.shiftCalls, shiftsBefore + 1);
  });

  testWidgets('si no es de las suyas muestra el texto y recarga', (
    tester,
  ) async {
    final agenda = _Agenda();
    final cancel = _Cancel()
      ..errors.add(
        const DoctorCancellationException(
          DoctorCancellationFailure.notFound,
          _notFound,
        ),
      );
    await _pump(tester, agenda, cancel);
    final shiftsBefore = agenda.shiftCalls;
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(find.text(_notFound), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(agenda.shiftCalls, shiftsBefore + 1);
  });

  testWidgets('el conflicto de interés no recarga', (tester) async {
    final agenda = _Agenda();
    final cancel = _Cancel()
      ..errors.add(
        const DoctorCancellationException(
          DoctorCancellationFailure.conflictOfInterest,
          _conflict,
        ),
      );
    await _pump(tester, agenda, cancel);
    final shiftsBefore = agenda.shiftCalls;
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(find.text(_conflict), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(agenda.shiftCalls, shiftsBefore);
  });

  testWidgets('un error genérico muestra su mensaje', (tester) async {
    final cancel = _Cancel()..errors.add(const ApiException(_generic));
    await _pump(tester, _Agenda(), cancel);
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(find.text(_generic), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('tras un error, confirmar de nuevo llama otra vez', (
    tester,
  ) async {
    final cancel = _Cancel()
      ..errors.add(
        const DoctorCancellationException(
          DoctorCancellationFailure.outsideWindow,
          _outsideWindow,
        ),
      );
    await _pump(tester, _Agenda(), cancel);
    await _open(tester, 11);
    await _typeReason(tester, 'Imprevisto de guardia');
    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirm-cancel')));
    await tester.pumpAndSettle();

    expect(cancel.calls, [
      (11, 'Imprevisto de guardia'),
      (11, 'Imprevisto de guardia'),
    ]);
  });

  testWidgets(
    'el motivo llega a 1000 y el diálogo no se cierra al tocar afuera',
    (tester) async {
      await _pump(tester, _Agenda(), _Cancel());
      await _open(tester, 11);

      final field = tester.widget<TextField>(
        find.byKey(const Key('cancel-reason-field')),
      );
      final route = ModalRoute.of(tester.element(find.byType(AlertDialog)));

      expect(field.maxLength, 1000);
      expect(route!.barrierDismissible, isFalse);
    },
  );

  group('a 320 px de ancho (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('la lista y el diálogo no desbordan', (tester) async {
      await _pump(tester, _Agenda(), _Cancel(), size: const Size(320, 640));

      await tester.scrollUntilVisible(
        find.byKey(const Key('doctor-number-2')),
        200,
      );

      expect(find.text('Luis Gómez · CI 2.222.222-2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _open(tester, 11);

      expect(find.text(_luisBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
