import 'dart:async';

import 'package:agenda_medica/features/agendas/models/schedule_entry.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/models/staff_cancellation_result.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_repository_provider.dart';
import 'package:agenda_medica/features/agendas/providers/staff_cancellation_repository_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_page_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_today_provider.dart';
import 'package:agenda_medica/features/agendas/repositories/schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/staff_cancellation_repository.dart';
import 'package:agenda_medica/features/agendas/widgets/schedule_results.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

class _ScheduleRepository implements ScheduleRepository {
  _ScheduleRepository(this.entry);

  final ScheduleEntry entry;
  int searchCalls = 0;

  @override
  Future<SchedulePage> search(ScheduleFilters filters) async {
    searchCalls++;
    return SchedulePage(items: [entry], page: 0, size: 20, total: 1);
  }
}

class _CancellationRepository implements StaffCancellationRepository {
  StaffCancellationResult? result;
  StaffCancellationException? exception;
  Completer<void>? completer;
  int cancelCalls = 0;
  final cancelledIds = <int>[];

  @override
  Future<StaffCancellationResult> cancel(int id) async {
    cancelCalls++;
    cancelledIds.add(id);
    final pending = completer;
    if (pending != null) await pending.future;
    if (exception != null) throw exception!;
    return result!;
  }
}

const _doctor = DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez');
const _clinic = Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2');
const _specialty = Specialty(
  id: 3,
  name: 'Cardiología',
  requiresReferral: true,
);

ScheduleEntry _entry(String status, {int id = 9001}) => ScheduleEntry(
  appointmentId: id,
  member: const ScheduleMember(
    ci: '45678911',
    firstName: 'Lucía',
    lastName: 'Fernández',
  ),
  doctor: _doctor,
  specialty: _specialty,
  date: DateTime.utc(2026, 10, 30),
  startMinutes: 780,
  endMinutes: 810,
  clinic: _clinic,
  status: status,
  arrivedAt: null,
);

Future<void> _pump(
  WidgetTester tester, {
  required ScheduleEntry entry,
  required _CancellationRepository cancellation,
  _ScheduleRepository? schedules,
  Size size = const Size(1300, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  schedules ??= _ScheduleRepository(entry);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        scheduleRepositoryProvider.overrideWith((ref) async => schedules!),
        schedulesTodayProvider.overrideWithValue(entry.date),
        staffCancellationRepositoryProvider.overrideWith(
          (ref) async => cancellation,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, child) {
              final page = ref.watch(schedulesPageProvider);
              return page.when(
                data: (data) =>
                    SingleChildScrollView(child: ScheduleResults(page: data)),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text('$error'),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openDialog(WidgetTester tester) async {
  final button = find.byKey(const Key('cancel-schedule-9001'));
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('botón de cancelar', () {
    for (final size in [const Size(1300, 1800), const Size(400, 1800)]) {
      testWidgets('solo AGENDADA en ${size.width}px', (tester) async {
        await _pump(
          tester,
          entry: _entry('AGENDADA'),
          cancellation: _CancellationRepository(),
          size: size,
        );
        expect(find.byKey(const Key('cancel-schedule-9001')), findsOneWidget);
      });
    }

    for (final status in [
      'ATENDIDA',
      'CANCELADA_SOCIO',
      'CANCELADA_INSTITUCION',
      'NO_SE_PRESENTO',
      'NO_ASISTIO',
      'NO_ATENDIDA',
    ]) {
      for (final size in [const Size(1300, 1800), const Size(400, 1800)]) {
        testWidgets('$status no muestra el botón en ${size.width}px', (
          tester,
        ) async {
          await _pump(
            tester,
            entry: _entry(status),
            cancellation: _CancellationRepository(),
            size: size,
          );
          expect(find.byKey(const Key('cancel-schedule-9001')), findsNothing);
        });
      }
    }
  });

  testWidgets('abre el diálogo y Volver no cancela', (tester) async {
    final cancellation = _CancellationRepository();
    await _pump(tester, entry: _entry('AGENDADA'), cancellation: cancellation);

    final cancelButton = find.byKey(const Key('cancel-schedule-9001'));
    expect(cancelButton, findsOneWidget);
    await tester.ensureVisible(cancelButton);
    await tester.pump();
    await tester.tap(cancelButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('¿Cancelar la consulta?'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Lucía Fernández'),
      ),
      findsOneWidget,
    );
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
        matching: find.textContaining('30/10/2026'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('13:00'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          'La cancelación es a pedido del socio y se le avisa por notificación.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const Key('dismiss-cancel-schedule-dialog')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const Key('confirm-cancel-schedule')),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const Key('dismiss-cancel-schedule-dialog')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(cancellation.cancelCalls, 0);
  });

  testWidgets('confirmar pendiente bloquea cierre y evita doble llamada', (
    tester,
  ) async {
    final cancellation = _CancellationRepository()
      ..completer = Completer<void>();
    await _pump(tester, entry: _entry('AGENDADA'), cancellation: cancellation);
    await _openDialog(tester);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('¿Cancelar la consulta?'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Lucía Fernández'),
      ),
      findsOneWidget,
    );
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
        matching: find.textContaining('30/10/2026'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('13:00'),
      ),
      findsOneWidget,
    );
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byKey(const Key('confirm-cancel-schedule')),
    );

    final button = tester.widget<OutlinedButton>(confirm);
    button.onPressed!();
    button.onPressed!();
    await tester.pump();

    expect(cancellation.cancelCalls, 1);
    expect(cancellation.cancelledIds, [9001]);
    expect((tester.widget(confirm) as OutlinedButton).onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('éxito sin pase muestra el aviso y refresca', (tester) async {
    final cancellation = _CancellationRepository();
    cancellation.result = StaffCancellationResult(
      appointmentId: 9001,
      status: 'CANCELADA_SOCIO',
      cancelledAt: DateTime.utc(2026, 10, 30, 13),
      referralReturned: false,
    );
    final schedules = _ScheduleRepository(_entry('AGENDADA'));
    await _pump(
      tester,
      entry: _entry('AGENDADA'),
      cancellation: cancellation,
      schedules: schedules,
    );
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(schedules.searchCalls, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Consulta cancelada.'), findsOneWidget);
  });

  testWidgets('éxito con pase muestra el aviso y refresca', (tester) async {
    final cancellation = _CancellationRepository();
    cancellation.result = StaffCancellationResult(
      appointmentId: 9001,
      status: 'CANCELADA_SOCIO',
      cancelledAt: DateTime.utc(2026, 10, 30, 13),
      referralReturned: true,
    );
    final schedules = _ScheduleRepository(_entry('AGENDADA'));
    await _pump(
      tester,
      entry: _entry('AGENDADA'),
      cancellation: cancellation,
      schedules: schedules,
    );
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(schedules.searchCalls, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text('Consulta cancelada. El pase volvió a estar disponible.'),
      findsOneWidget,
    );
  });

  for (final errorCase in [
    (StaffCancellationFailure.outsideWindow, 'Fuera de plazo.', false),
    (StaffCancellationFailure.notScheduled, 'No agendada.', true),
    (StaffCancellationFailure.notFound, 'No encontrada.', true),
    (StaffCancellationFailure.conflictOfInterest, 'Conflicto.', false),
  ]) {
    testWidgets('${errorCase.$1} muestra el error', (tester) async {
      final cancellation = _CancellationRepository()
        ..exception = StaffCancellationException(errorCase.$1, errorCase.$2);
      final schedules = _ScheduleRepository(_entry('AGENDADA'));
      await _pump(
        tester,
        entry: _entry('AGENDADA'),
        cancellation: cancellation,
        schedules: schedules,
      );
      await _openDialog(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byKey(const Key('confirm-cancel-schedule')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byKey(const Key('cancel-schedule-error')),
        ),
        findsOneWidget,
      );
      expect(schedules.searchCalls, errorCase.$3 ? 2 : 1);
      expect(find.byType(AlertDialog), findsOneWidget);
    });
  }

  testWidgets('errores de autenticación tienen mensajes propios', (
    tester,
  ) async {
    final cancellation = _CancellationRepository()
      ..exception = const StaffCancellationException(
        StaffCancellationFailure.unauthenticated,
        'vencida',
      );
    await _pump(tester, entry: _entry('AGENDADA'), cancellation: cancellation);
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Tu sesión venció. Iniciá sesión nuevamente.'),
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const Key('cancel-schedule-error')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('prohibido mantiene el diálogo abierto con el mensaje', (
    tester,
  ) async {
    final cancellation = _CancellationRepository()
      ..exception = const StaffCancellationException(
        StaffCancellationFailure.forbidden,
        'prohibida',
      );
    await _pump(tester, entry: _entry('AGENDADA'), cancellation: cancellation);
    await _openDialog(tester);
    await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(
          'Tu cuenta no tiene permiso para cancelar consultas.',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byKey(const Key('cancel-schedule-error')),
      ),
      findsOneWidget,
    );
  });

  group('cancelación a 320 px con Roboto', () {
    setUpAll(loadRoboto);

    testWidgets('un error largo no desborda', (tester) async {
      final cancellation = _CancellationRepository()
        ..exception = const StaffCancellationException(
          StaffCancellationFailure.other,
          'Este mensaje explica un problema largo de cancelación para comprobar '
          'que el diálogo puede mostrarlo sin desbordes en pantalla angosta.',
        );
      await _pump(
        tester,
        entry: _entry('AGENDADA'),
        cancellation: cancellation,
        size: const Size(320, 1800),
      );
      await _openDialog(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
