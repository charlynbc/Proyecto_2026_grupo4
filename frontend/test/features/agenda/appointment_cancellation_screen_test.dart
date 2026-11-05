import 'dart:async';

import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/cancellation_result.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_cancellation_provider.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_cancellation_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

class _HistoryRepository implements AppointmentHistoryRepository {
  _HistoryRepository({required this.appointment});

  final Appointment appointment;
  int getCalls = 0;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async =>
      AppointmentHistoryPage(
        items: [appointment],
        page: query.page,
        size: query.size,
        total: 1,
      );

  @override
  Future<Appointment> get(int id) async {
    getCalls++;
    return appointment;
  }
}

class _CancellationRepository implements AppointmentCancellationRepository {
  CancellationResult? result;
  CancellationException? exception;
  Completer<void>? completer;
  int cancelCalls = 0;
  final cancelledIds = <int>[];

  @override
  Future<CancellationResult> cancel(int id) async {
    cancelCalls++;
    cancelledIds.add(id);
    if (completer != null) await completer!.future;
    if (exception != null) throw exception!;
    return result!;
  }
}

Appointment _appointment({required String status, int? referralId}) =>
    Appointment(
      id: 9001,
      status: status,
      date: DateTime.utc(2026, 10, 20),
      number: 2,
      startMinutes: 780,
      endMinutes: 810,
      doctor: DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez'),
      specialty: Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
      clinic: Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
      referralId: referralId,
      bookedAt: DateTime.parse('2026-10-20T10:12:45-03:00'),
      cancelledAt: null,
      cancellationReason: null,
    );

Future<void> _pump(
  WidgetTester tester, {
  required String status,
  int? referralId,
  required _HistoryRepository history,
  required _CancellationRepository cancellation,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => history,
        ),
        appointmentCancellationRepositoryProvider.overrideWith(
          (ref) async => cancellation,
        ),
      ],
      child: const MaterialApp(home: AppointmentDetailScreen(id: 9001)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cancel-appointment')));
  await tester.pumpAndSettle();
}

bool _isEnabled(WidgetTester tester, String key) =>
    (tester.widget(find.byKey(Key(key))) as dynamic).onPressed != null;

void main() {
  testWidgets('solo AGENDADA muestra el botón de cancelar', (tester) async {
    for (final status in [
      'AGENDADA',
      'ATENDIDA',
      'CANCELADA_SOCIO',
      'CANCELADA_INSTITUCION',
      'NO_SE_PRESENTO',
      'NO_ASISTIO',
      'NO_ATENDIDA',
    ]) {
      final history = _HistoryRepository(
        appointment: _appointment(status: status),
      );
      final cancellation = _CancellationRepository();
      await _pump(
        tester,
        status: status,
        history: history,
        cancellation: cancellation,
      );

      expect(
        find.byKey(const Key('cancel-appointment')),
        status == 'AGENDADA' ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('cancel-appointment-disabled')),
        findsNothing,
      );
      expect(find.byKey(const Key('cancellation-pending')), findsNothing);
    }
  });

  testWidgets('abre el diálogo con los datos de la consulta', (tester) async {
    final history = _HistoryRepository(
      appointment: _appointment(status: 'AGENDADA'),
    );
    await _pump(
      tester,
      status: 'AGENDADA',
      history: history,
      cancellation: _CancellationRepository(),
    );
    await _openDialog(tester);

    expect(find.text('¿Cancelar la consulta?'), findsOneWidget);
    expect(find.byKey(const Key('dismiss-cancel-dialog')), findsOneWidget);
    expect(find.byKey(const Key('confirm-cancel-appointment')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Cardiología'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('20/10/2026'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Volver cierra sin cancelar', (tester) async {
    final cancellation = _CancellationRepository();
    final history = _HistoryRepository(
      appointment: _appointment(status: 'AGENDADA'),
    );
    await _pump(
      tester,
      status: 'AGENDADA',
      history: history,
      cancellation: cancellation,
    );
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('dismiss-cancel-dialog')));
    await tester.pumpAndSettle();

    expect(find.text('¿Cancelar la consulta?'), findsNothing);
    expect(cancellation.cancelCalls, 0);
  });

  testWidgets('informa la devolución según el pase', (tester) async {
    for (final referralId in [null, 5]) {
      final history = _HistoryRepository(
        appointment: _appointment(status: 'AGENDADA', referralId: referralId),
      );
      await _pump(
        tester,
        status: 'AGENDADA',
        referralId: referralId,
        history: history,
        cancellation: _CancellationRepository(),
      );
      await _openDialog(tester);

      expect(
        find.text('Si el pase sigue vigente, lo recuperás.'),
        referralId == null ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('el botón atrás no cierra el diálogo mientras cancela', (
    tester,
  ) async {
    final pending = Completer<void>();
    final cancellation = _CancellationRepository()
      ..completer = pending
      ..result = CancellationResult(
        appointmentId: 9001,
        status: 'CANCELADA_SOCIO',
        cancelledAt: DateTime.utc(2026, 10, 20),
        referralReturned: false,
      );
    final history = _HistoryRepository(
      appointment: _appointment(status: 'AGENDADA'),
    );
    await _pump(
      tester,
      status: 'AGENDADA',
      history: history,
      cancellation: cancellation,
    );
    await _openDialog(tester);

    await tester.tap(find.byKey(const Key('confirm-cancel-appointment')));
    await tester.pump();

    expect(_isEnabled(tester, 'confirm-cancel-appointment'), isFalse);
    expect(_isEnabled(tester, 'dismiss-cancel-dialog'), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('¿Cancelar la consulta?'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('¿Cancelar la consulta?'), findsOneWidget);
    expect(_isEnabled(tester, 'confirm-cancel-appointment'), isFalse);
    expect(_isEnabled(tester, 'dismiss-cancel-dialog'), isFalse);
    pending.complete();
  });

  testWidgets(
    'dos disparos seguidos de confirmar envían una sola cancelación',
    (tester) async {
      final pending = Completer<void>();
      final cancellation = _CancellationRepository()
        ..completer = pending
        ..result = CancellationResult(
          appointmentId: 9001,
          status: 'CANCELADA_SOCIO',
          cancelledAt: DateTime.utc(2026, 10, 20),
          referralReturned: false,
        );
      final history = _HistoryRepository(
        appointment: _appointment(status: 'AGENDADA'),
      );
      await _pump(
        tester,
        status: 'AGENDADA',
        history: history,
        cancellation: cancellation,
      );
      await _openDialog(tester);

      final onPressed =
          (tester.widget(
                find.byKey(const Key('confirm-cancel-appointment')),
              ) as dynamic).onPressed
              as VoidCallback;
      // Caso realista: dos toques muy rápidos antes de que el botón se reconstruya como deshabilitado.
      onPressed();
      onPressed();
      await tester.pump();
      expect(cancellation.cancelCalls, 1);
      expect(cancellation.cancelledIds, [9001]);
      pending.complete();
    },
  );

  for (final referralReturned in [false, true]) {
    testWidgets('cancelación exitosa devuelve el resultado y refresca', (
      tester,
    ) async {
      final cancellation = _CancellationRepository()
        ..result = CancellationResult(
          appointmentId: 9001,
          status: 'CANCELADA_SOCIO',
          cancelledAt: DateTime.utc(2026, 10, 20),
          referralReturned: referralReturned,
        );
      final history = _HistoryRepository(
        appointment: _appointment(status: 'AGENDADA'),
      );
      await _pump(
        tester,
        status: 'AGENDADA',
        history: history,
        cancellation: cancellation,
      );
      await _openDialog(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-appointment')));
      await tester.pumpAndSettle();

      expect(find.text('¿Cancelar la consulta?'), findsNothing);
      expect(history.getCalls, 2);
      expect(
        find.text(
          referralReturned
              ? 'Consulta cancelada. Recuperaste tu pase.'
              : 'Consulta cancelada.',
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('outsideWindow mantiene el diálogo y no refresca', (
    tester,
  ) async {
    final cancellation = _CancellationRepository()
      ..exception = const CancellationException(
        CancellationFailure.outsideWindow,
        'No se puede cancelar con menos de 2 horas de anticipación.',
      );
    final history = _HistoryRepository(
      appointment: _appointment(status: 'AGENDADA'),
    );
    await _pump(
      tester,
      status: 'AGENDADA',
      history: history,
      cancellation: cancellation,
    );
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-cancel-appointment')));
    await tester.pumpAndSettle();

    expect(find.text('¿Cancelar la consulta?'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cancel-error'))).data,
      'No se puede cancelar con menos de 2 horas de anticipación.',
    );
    expect(history.getCalls, 1);
    expect(_isEnabled(tester, 'confirm-cancel-appointment'), isTrue);
    expect(_isEnabled(tester, 'dismiss-cancel-dialog'), isTrue);
  });

  for (final failure in [
    (CancellationFailure.notScheduled, 'La consulta ya no está agendada.'),
    (CancellationFailure.notFound, 'No se encontró la consulta.'),
  ]) {
    testWidgets('${failure.$1} refresca el detalle y muestra el mensaje', (
      tester,
    ) async {
      final cancellation = _CancellationRepository()
        ..exception = CancellationException(failure.$1, failure.$2);
      final history = _HistoryRepository(
        appointment: _appointment(status: 'AGENDADA'),
      );
      await _pump(
        tester,
        status: 'AGENDADA',
        history: history,
        cancellation: cancellation,
      );
      await _openDialog(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-appointment')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cancel-error')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('cancel-error'))).data,
        failure.$2,
      );
      expect(history.getCalls, 2);
    });
  }

  testWidgets('después de un error se puede confirmar nuevamente', (
    tester,
  ) async {
    final cancellation = _CancellationRepository()
      ..exception = const CancellationException(
        CancellationFailure.notFound,
        'No encontrada',
      );
    final history = _HistoryRepository(
      appointment: _appointment(status: 'AGENDADA'),
    );
    await _pump(
      tester,
      status: 'AGENDADA',
      history: history,
      cancellation: cancellation,
    );
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-cancel-appointment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-appointment')));
    await tester.pumpAndSettle();

    expect(cancellation.cancelCalls, 2);
  });

  for (final entry in [
    (
      CancellationFailure.unauthenticated,
      'Mensaje distinto de autenticación',
      'Tu sesión venció. Iniciá sesión nuevamente.',
    ),
    (
      CancellationFailure.forbidden,
      'Mensaje distinto de permisos',
      'Tu cuenta no tiene permiso para cancelar consultas.',
    ),
  ]) {
    testWidgets('${entry.$1} usa el mensaje fijo de cancelación', (
      tester,
    ) async {
      final cancellation = _CancellationRepository()
        ..exception = CancellationException(entry.$1, entry.$2);
      final history = _HistoryRepository(
        appointment: _appointment(status: 'AGENDADA'),
      );
      await _pump(
        tester,
        status: 'AGENDADA',
        history: history,
        cancellation: cancellation,
      );
      await _openDialog(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-appointment')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('cancel-error'))).data,
        entry.$3,
      );
    });
  }

  group('cancelación con Roboto', () {
    setUpAll(loadRoboto);

    testWidgets('muestra el botón de cancelar', (tester) async {
      final history = _HistoryRepository(
        appointment: _appointment(status: 'AGENDADA'),
      );
      await _pump(
        tester,
        status: 'AGENDADA',
        history: history,
        cancellation: _CancellationRepository(),
      );

      expect(find.byKey(const Key('cancel-appointment')), findsOneWidget);
    });
  });
}
