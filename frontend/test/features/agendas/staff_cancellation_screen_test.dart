import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
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
  Object? exception;
  Completer<void>? completer;
  int cancelCalls = 0;
  final cancelledIds = <int>[];
  final reasons = <String?>[];

  @override
  Future<StaffCancellationResult> cancel(int id, {String? reason}) async {
    cancelCalls++;
    cancelledIds.add(id);
    reasons.add(reason);
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
    (
      StaffCancellationFailure.outsideWindow,
      'La cancelación debe solicitarse con al menos dos horas de anticipación.',
      false,
    ),
    (
      StaffCancellationFailure.notScheduled,
      'La consulta ya no está agendada.',
      true,
    ),
    (StaffCancellationFailure.notFound, 'No se encontró la consulta.', true),
    (
      StaffCancellationFailure.conflictOfInterest,
      'Conflicto de interés con el socio.',
      false,
    ),
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
      expect(
        tester
            .widget<Text>(find.byKey(const Key('cancel-schedule-error')))
            .data,
        errorCase.$2,
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

  testWidgets('validación muestra el mensaje exacto y no refresca el listado', (
    tester,
  ) async {
    final cancellation = _CancellationRepository()
      ..exception = const StaffCancellationException(
        StaffCancellationFailure.validation,
        'El identificador de la consulta no es valido.',
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
    await tester.pump(const Duration(seconds: 1));

    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byKey(const Key('cancel-schedule-error')),
            ),
          )
          .data,
      'El identificador de la consulta no es valido.',
    );
    expect(schedules.searchCalls, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets(
    'otro error muestra el mensaje exacto y deja el diálogo abierto',
    (tester) async {
      final cancellation = _CancellationRepository()
        ..exception = const StaffCancellationException(
          StaffCancellationFailure.other,
          'Fallo inesperado del servidor.',
        );
      await _pump(
        tester,
        entry: _entry('AGENDADA'),
        cancellation: cancellation,
      );
      await _openDialog(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byKey(const Key('cancel-schedule-error')),
              ),
            )
            .data,
        'Fallo inesperado del servidor.',
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

  testWidgets(
    'error no esperado muestra el mensaje genérico y deja el diálogo abierto',
    (tester) async {
      final cancellation = _CancellationRepository()
        ..exception = StateError('x');
      await _pump(
        tester,
        entry: _entry('AGENDADA'),
        cancellation: cancellation,
      );
      await _openDialog(tester);
      await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byKey(const Key('cancel-schedule-error')),
              ),
            )
            .data,
        kApiGenericMessage,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
    },
  );

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

  group('cancelar por otro motivo', () {
    final inDialog = find.byType(AlertDialog);
    final causeSocio = find.byKey(const Key('cancel-cause-socio'));
    final causeOther = find.byKey(const Key('cancel-cause-other'));
    final reasonField = find.byKey(const Key('cancel-schedule-reason'));
    final confirm = find.byKey(const Key('confirm-cancel-schedule'));

    StaffCancellationResult result(String status, {bool referral = false}) =>
        StaffCancellationResult(
          appointmentId: 9001,
          status: status,
          cancelledAt: DateTime.utc(2026, 10, 30, 13),
          referralReturned: referral,
        );

    Future<_CancellationRepository> open(
      WidgetTester tester, {
      String status = 'CANCELADA_INSTITUCION',
      Size size = const Size(1300, 1800),
    }) async {
      final cancellation = _CancellationRepository()..result = result(status);
      await _pump(
        tester,
        entry: _entry('AGENDADA'),
        cancellation: cancellation,
        size: size,
      );
      await _openDialog(tester);
      return cancellation;
    }

    Future<void> chooseOther(WidgetTester tester) async {
      // En pantalla angosta con texto grande hay que desplazar el diálogo.
      await tester.ensureVisible(causeOther);
      await tester.tap(causeOther);
      await tester.pump();
    }

    Future<void> confirmAndSettle(WidgetTester tester) async {
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('ofrece las dos causas, con A pedido del socio elegida y sin '
        'campo de motivo', (tester) async {
      await open(tester);

      expect(find.text('A pedido del socio'), findsOneWidget);
      expect(find.text('Otro motivo (administrativo u otro)'), findsOneWidget);
      expect(reasonField, findsNothing);
      expect(
        find.text(
          'La cancelación es a pedido del socio y se le avisa por notificación.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('A pedido del socio cancela sin motivo', (tester) async {
      final cancellation = await open(tester, status: 'CANCELADA_SOCIO');

      await confirmAndSettle(tester);

      expect(cancellation.reasons, [null]);
      expect(find.text('Consulta cancelada.'), findsOneWidget);
    });

    testWidgets('Otro motivo muestra el campo con contador de 1000 y avisa '
        'que el socio ve el motivo', (tester) async {
      await open(tester);

      await chooseOther(tester);

      expect(reasonField, findsOneWidget);
      expect(find.text('0/1000'), findsOneWidget);
      expect(find.text('Motivo de la cancelación'), findsOneWidget);
      expect(
        find.text(
          'El socio va a ver el motivo en el detalle de su consulta y en la '
          'notificación.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'La cancelación es a pedido del socio y se le avisa por notificación.',
        ),
        findsNothing,
      );
    });

    for (final blank in ['', '    ']) {
      testWidgets('Otro motivo con el campo vacío ("$blank") muestra el error '
          'y no cancela', (tester) async {
        final cancellation = await open(tester);
        await chooseOther(tester);
        if (blank.isNotEmpty) await tester.enterText(reasonField, blank);

        await confirmAndSettle(tester);

        expect(
          find.text('Escribí el motivo de la cancelación.'),
          findsOneWidget,
        );
        expect(cancellation.cancelCalls, 0);
        expect(inDialog, findsOneWidget);
      });
    }

    testWidgets('el error del campo vacío se va al escribir', (tester) async {
      await open(tester);
      await chooseOther(tester);
      await confirmAndSettle(tester);
      expect(find.text('Escribí el motivo de la cancelación.'), findsOneWidget);

      await tester.enterText(reasonField, 'G');
      await tester.pump();

      expect(find.text('Escribí el motivo de la cancelación.'), findsNothing);
    });

    testWidgets('Otro motivo manda el motivo recortado y avisa que el socio '
        'lo puede ver', (tester) async {
      final cancellation = await open(tester);
      await chooseOther(tester);
      await tester.enterText(reasonField, '  Se rompió el equipo  ');

      await confirmAndSettle(tester);

      expect(cancellation.cancelledIds, [9001]);
      expect(cancellation.reasons, ['Se rompió el equipo']);
      expect(inDialog, findsNothing);
      expect(
        find.text(
          'Consulta cancelada por otro motivo. El socio puede ver el '
          'motivo.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Otro motivo con pase devuelto lo dice', (tester) async {
      final cancellation = await open(tester);
      cancellation.result = result('CANCELADA_INSTITUCION', referral: true);
      await chooseOther(tester);
      await tester.enterText(reasonField, 'Guardia');

      await confirmAndSettle(tester);

      expect(
        find.text(
          'Consulta cancelada por otro motivo. El socio puede ver el '
          'motivo. El pase volvió a estar disponible.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('si el servidor responde CANCELADA_SOCIO avisa que no '
        'registró el motivo', (tester) async {
      final cancellation = await open(tester, status: 'CANCELADA_SOCIO');
      await chooseOther(tester);
      await tester.enterText(reasonField, 'Guardia');

      await confirmAndSettle(tester);

      expect(cancellation.reasons, ['Guardia']);
      expect(inDialog, findsNothing);
      expect(
        find.text(
          'La consulta se canceló, pero el sistema no guardó el '
          'motivo. El socio no lo va a ver: avisale por otro medio.',
        ),
        findsOneWidget,
      );
      expect(find.text('Consulta cancelada.'), findsNothing);
    });

    testWidgets('el campo no deja pasar de 1000 caracteres', (tester) async {
      await open(tester);
      await chooseOther(tester);

      await tester.enterText(reasonField, 'a' * 1001);
      await tester.pump();

      expect(
        tester.widget<TextField>(reasonField).controller!.text.length,
        1000,
      );
      expect(find.text('1000/1000'), findsOneWidget);
    });

    testWidgets('Volver después de elegir Otro motivo no cancela', (
      tester,
    ) async {
      final cancellation = await open(tester);
      await chooseOther(tester);
      await tester.enterText(reasonField, 'Guardia');

      await tester.tap(find.byKey(const Key('dismiss-cancel-schedule-dialog')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(inDialog, findsNothing);
      expect(cancellation.cancelCalls, 0);
    });

    testWidgets('volver a A pedido del socio no manda el motivo escrito', (
      tester,
    ) async {
      final cancellation = await open(tester, status: 'CANCELADA_SOCIO');
      await chooseOther(tester);
      await tester.enterText(reasonField, 'Guardia');
      await tester.tap(causeSocio);
      await tester.pump();

      await confirmAndSettle(tester);

      expect(reasonField, findsNothing);
      expect(cancellation.reasons, [null]);
    });

    testWidgets('mientras se envía se apagan las opciones y el campo', (
      tester,
    ) async {
      final cancellation = await open(tester);
      cancellation.completer = Completer<void>();
      await chooseOther(tester);
      await tester.enterText(reasonField, 'Guardia');

      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump();

      expect(tester.widget<TextField>(reasonField).enabled, isFalse);
      expect(
        tester.widget<RadioListTile<Object?>>(causeSocio).enabled,
        isFalse,
      );
      expect(
        tester.widget<RadioListTile<Object?>>(causeOther).enabled,
        isFalse,
      );
      expect(cancellation.cancelCalls, 1);
    });

    testWidgets('un error del servidor se muestra y deja reintentar', (
      tester,
    ) async {
      final cancellation = await open(tester);
      cancellation.exception = const StaffCancellationException(
        StaffCancellationFailure.validation,
        'El motivo no puede tener más de 1000 caracteres.',
      );
      await chooseOther(tester);
      await tester.enterText(reasonField, 'Guardia');

      await confirmAndSettle(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('cancel-schedule-error')))
            .data,
        'El motivo no puede tener más de 1000 caracteres.',
      );
      expect(inDialog, findsOneWidget);
      expect(tester.widget<TextField>(reasonField).controller!.text, 'Guardia');
    });

    group('a 320 px con Roboto y el texto al doble', () {
      setUpAll(loadRoboto);

      testWidgets('el diálogo con Otro motivo no desborda y se puede '
          'confirmar', (tester) async {
        final cancellation = await open(tester, size: const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();
        expect(
          MediaQuery.of(tester.element(inDialog)).textScaler.scale(10),
          20,
        );
        await chooseOther(tester);
        await tester.ensureVisible(reasonField);
        await tester.enterText(reasonField, 'Se rompió el equipo');
        await tester.pump();

        expect(tester.takeException(), isNull);
        await confirmAndSettle(tester);

        expect(tester.takeException(), isNull);
        expect(cancellation.reasons, ['Se rompió el equipo']);
      });

      testWidgets('el error del campo vacío no desborda', (tester) async {
        await open(tester, size: const Size(320, 640));
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pump();
        await chooseOther(tester);

        await confirmAndSettle(tester);

        expect(
          find.text('Escribí el motivo de la cancelación.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    });
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
