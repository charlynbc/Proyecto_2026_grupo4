import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/agenda/models/agenda_time.dart';
import 'package:agenda_medica/features/medico/models/doctor_cancellation_result.dart';
import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/models/doctor_shift_cancellation_result.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/medico/providers/doctor_cancellation_repository_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_shift_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

class Agenda implements DoctorShiftRepository {
  int calls = 0;
  @override
  Future<List<DoctorShift>> listShifts(String date) async {
    calls++;
    DoctorShift shift(int id, String date, String status) => DoctorShift(
      id: id,
      date: date,
      startTime: '09:00',
      endTime: '10:00',
      specialtyName: 'Cardiología',
      clinicName: 'Uno',
      status: status,
      numbersCount: 2,
      reservedCount: 2,
    );
    return [
      shift(301, '2099-12-31', 'ACTIVO'),
      shift(302, '2099-12-31', 'SUSPENDIDO'),
      shift(303, '2020-01-01', 'ACTIVO'),
      shift(304, formatApiDate(UruguayTime.today()), 'ACTIVO'),
    ];
  }

  @override
  Future<DoctorShiftNumbers> listNumbers(
    int shiftId, {
    bool? arrived,
    DoctorNumbersOrder order = DoctorNumbersOrder.time,
    bool ascending = true,
  }) async => DoctorShiftNumbers(shiftId: shiftId, items: []);
}

class Cancel implements DoctorCancellationRepository {
  final calls = <(int, String)>[];
  Object? error;
  int count = 2;
  int passes = 1;
  @override
  Future<DoctorCancellationResult> cancelAppointment(int id, String reason) =>
      throw UnimplementedError();
  @override
  Future<DoctorShiftCancellationResult> cancelShift(
    int id,
    String reason,
  ) async {
    calls.add((id, reason));
    if (error != null) throw error!;
    return DoctorShiftCancellationResult(
      shiftId: id,
      date: DateTime.utc(2099, 12, 31),
      status: 'SUSPENDIDO',
      cancelledCount: count,
      returnedReferralsCount: passes,
    );
  }
}

Future<void> pumpScreen(
  WidgetTester tester,
  Agenda agenda,
  Cancel cancel,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith((ref) async => agenda),
        doctorCancellationRepositoryProvider.overrideWith(
          (ref) async => cancel,
        ),
        doctorPollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
      ],
      child: const MaterialApp(home: DoctorShiftsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cancel-shift-301')));
  await tester.pumpAndSettle();
}

void main() {
  group('pantalla angosta', () {
    setUpAll(loadRoboto);
    testWidgets('diálogo sin desbordes a 320 px', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpScreen(tester, Agenda(), Cancel());
      await open(tester);
      expect(tester.takeException(), isNull);
    });
  });
  testWidgets('botón solo en turnos activos de hoy o futuros y no selecciona', (
    tester,
  ) async {
    await pumpScreen(tester, Agenda(), Cancel());
    expect(find.byKey(const Key('cancel-shift-301')), findsOneWidget);
    expect(find.byKey(const Key('cancel-shift-302')), findsNothing);
    expect(find.byKey(const Key('cancel-shift-303')), findsNothing);
    expect(find.byKey(const Key('cancel-shift-304')), findsOneWidget);
    await open(tester);
    expect(find.text('¿Cancelar todo el turno?'), findsOneWidget);
    expect(find.textContaining('31/12/2099'), findsOneWidget);
    expect(find.textContaining('Cardiología'), findsWidgets);
    expect(find.text('Números del turno'), findsNothing);
  });
  testWidgets('confirma, refresca y muestra cantidades', (tester) async {
    final agenda = Agenda();
    final cancel = Cancel();
    await pumpScreen(tester, agenda, cancel);
    await open(tester);
    await tester.enterText(
      find.byKey(const Key('cancel-reason-field')),
      'Guardia',
    );
    await tester.tap(find.text('Cancelar turno').last);
    await tester.pumpAndSettle();
    expect(cancel.calls, [(301, 'Guardia')]);
    expect(agenda.calls, greaterThan(1));
    expect(
      find.text(
        'Turno cancelado. Se cancelaron 2 consultas. 1 pase volvió a estar disponible.',
      ),
      findsOneWidget,
    );
  });
  for (final (count, passes, message) in [
    (0, 0, 'Turno cancelado. No había consultas agendadas.'),
    (
      1,
      3,
      'Turno cancelado. Se canceló 1 consulta. 3 pases volvieron a estar disponibles.',
    ),
  ]) {
    testWidgets('mensaje para $count consultas y $passes pases', (
      tester,
    ) async {
      final cancel = Cancel()
        ..count = count
        ..passes = passes;
      await pumpScreen(tester, Agenda(), cancel);
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('cancel-reason-field')),
        'Motivo',
      );
      await tester.tap(find.text('Cancelar turno').last);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
    });
  }
  for (final failure in [
    DoctorCancellationFailure.outsideWindow,
    DoctorCancellationFailure.conflictOfInterest,
    DoctorCancellationFailure.notFound,
    DoctorCancellationFailure.shiftNotCancellable,
  ]) {
    testWidgets('mantiene diálogo ante $failure', (tester) async {
      final agenda = Agenda();
      final cancel = Cancel()
        ..error = DoctorCancellationException(
          failure,
          cancelShiftMessage(failure),
        );
      await pumpScreen(tester, agenda, cancel);
      await open(tester);
      await tester.enterText(
        find.byKey(const Key('cancel-reason-field')),
        'Motivo',
      );
      await tester.tap(find.text('Cancelar turno').last);
      await tester.pumpAndSettle();
      expect(find.text(cancelShiftMessage(failure)), findsOneWidget);
      expect(find.text('¿Cancelar todo el turno?'), findsOneWidget);
      expect(
        agenda.calls,
        failure == DoctorCancellationFailure.notFound ||
                failure == DoctorCancellationFailure.shiftNotCancellable
            ? 2
            : 1,
      );
    });
  }
}
