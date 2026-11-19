import 'dart:ui' show Tristate;

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/theme/app_theme.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agendas/models/schedule_entry.dart';
import 'package:agenda_medica/features/agendas/models/schedule_filters.dart';
import 'package:agenda_medica/features/agendas/models/schedule_page.dart';
import 'package:agenda_medica/features/agendas/models/staff_cancellation_result.dart';
import 'package:agenda_medica/features/agendas/providers/schedule_repository_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_page_provider.dart';
import 'package:agenda_medica/features/agendas/providers/schedules_today_provider.dart';
import 'package:agenda_medica/features/agendas/providers/staff_cancellation_repository_provider.dart';
import 'package:agenda_medica/features/agendas/repositories/schedule_repository.dart';
import 'package:agenda_medica/features/agendas/repositories/staff_cancellation_repository.dart';
import 'package:agenda_medica/features/agendas/widgets/schedule_results.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/contrast.dart';

/// Con el error de plazo (`outsideWindow`) el botón "Cancelar consulta" queda
/// deshabilitado mientras el diálogo siga abierto: el plazo vale para las dos
/// causas y la hora solo avanza. Los demás errores no cambian.

const _window =
    'La cancelación debe solicitarse con al menos dos horas de anticipación.';

class _Schedules implements ScheduleRepository {
  _Schedules(this.entry);

  final ScheduleEntry entry;
  int searchCalls = 0;

  @override
  Future<SchedulePage> search(ScheduleFilters filters) async {
    searchCalls++;
    return SchedulePage(items: [entry], page: 0, size: 20, total: 1);
  }
}

class _Cancellation implements StaffCancellationRepository {
  _Cancellation(this.error);

  Object error;
  int calls = 0;
  final reasons = <String?>[];

  @override
  Future<StaffCancellationResult> cancel(int id, {String? reason}) async {
    calls++;
    reasons.add(reason);
    throw error;
  }
}

StaffCancellationException _failure(
  StaffCancellationFailure failure, [
  String message = 'Mensaje de prueba.',
]) => StaffCancellationException(failure, message);

final _entry = ScheduleEntry(
  appointmentId: 9001,
  member: const ScheduleMember(
    ci: '45678911',
    firstName: 'Lucía',
    lastName: 'Fernández',
  ),
  doctor: const DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez'),
  specialty: const Specialty(
    id: 3,
    name: 'Cardiología',
    requiresReferral: true,
  ),
  date: DateTime.utc(2026, 10, 30),
  startMinutes: 780,
  endMinutes: 810,
  clinic: const Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  status: 'AGENDADA',
  arrivedAt: null,
);

Future<(_Cancellation, _Schedules)> _pump(
  WidgetTester tester,
  Object error, {
  Size size = const Size(1300, 1800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cancellation = _Cancellation(error);
  final schedules = _Schedules(_entry);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        scheduleRepositoryProvider.overrideWith((ref) async => schedules),
        schedulesTodayProvider.overrideWithValue(_entry.date),
        staffCancellationRepositoryProvider.overrideWith(
          (ref) async => cancellation,
        ),
      ],
      child: MaterialApp(
        theme: appTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, child) => ref
                .watch(schedulesPageProvider)
                .when(
                  data: (data) =>
                      SingleChildScrollView(child: ScheduleResults(page: data)),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Text('$error'),
                ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return (cancellation, schedules);
}

Future<void> _openDialog(WidgetTester tester) async {
  final button = find.byKey(const Key('cancel-schedule-9001'));
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('confirm-cancel-schedule')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _close(WidgetTester tester) async {
  await tester.tap(_dismissButton);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

final _confirmButton = find.byKey(const Key('confirm-cancel-schedule'));
final _dismissButton = find.byKey(const Key('dismiss-cancel-schedule-dialog'));
final _errorText = find.byKey(const Key('cancel-schedule-error'));
final _errorIcon = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byIcon(Icons.error_outline),
);

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).onPressed != null;

Future<void> _chooseOther(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cancel-cause-other')));
  await tester.pump();
}

Future<void> _chooseMember(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('cancel-cause-socio')));
  await tester.pump();
}

void main() {
  group('con el error de plazo el botón queda deshabilitado', () {
    testWidgets('después del error "Cancelar consulta" no se puede apretar', (
      tester,
    ) async {
      await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      expect(_enabled(tester, _confirmButton), isTrue);

      await _confirm(tester);

      expect(_enabled(tester, _confirmButton), isFalse);
      expect(find.text('Cancelar consulta'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<Text>(_errorText).data, _window);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('tocar el botón deshabilitado no vuelve a pedir nada', (
      tester,
    ) async {
      final (cancellation, _) = await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _confirm(tester);
      expect(cancellation.calls, 1);

      await tester.tap(_confirmButton, warnIfMissed: false);
      await tester.pump();
      await tester.tap(_confirmButton, warnIfMissed: false);
      await tester.pump();

      expect(cancellation.calls, 1);
    });

    testWidgets('también con "Otro motivo" y el motivo escrito', (
      tester,
    ) async {
      final (cancellation, _) = await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _chooseOther(tester);
      await tester.enterText(
        find.byKey(const Key('cancel-schedule-reason')),
        'Se rompio el equipo',
      );

      await _confirm(tester);

      expect(cancellation.reasons, ['Se rompio el equipo']);
      expect(_enabled(tester, _confirmButton), isFalse);
      expect(tester.widget<Text>(_errorText).data, _window);
    });

    testWidgets('cambiar de causa no lo rehabilita y el mensaje se mantiene', (
      tester,
    ) async {
      await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _confirm(tester);

      await _chooseOther(tester);
      expect(_enabled(tester, _confirmButton), isFalse);
      expect(tester.widget<Text>(_errorText).data, _window);
      expect(_errorIcon, findsOneWidget);

      await _chooseMember(tester);
      expect(_enabled(tester, _confirmButton), isFalse);
      expect(tester.widget<Text>(_errorText).data, _window);
      expect(_errorIcon, findsOneWidget);
    });

    testWidgets('escribir o borrar el motivo tampoco lo rehabilita', (
      tester,
    ) async {
      await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _chooseOther(tester);
      await tester.enterText(
        find.byKey(const Key('cancel-schedule-reason')),
        'a',
      );
      await _confirm(tester);

      await tester.enterText(
        find.byKey(const Key('cancel-schedule-reason')),
        'otro',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('cancel-schedule-reason')),
        '',
      );
      await tester.pump();

      expect(_enabled(tester, _confirmButton), isFalse);
      expect(tester.widget<Text>(_errorText).data, _window);
    });

    testWidgets('"Volver" sigue habilitado y cierra el diálogo', (
      tester,
    ) async {
      await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _confirm(tester);

      expect(_enabled(tester, _dismissButton), isTrue);
      await _close(tester);

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('al cerrar y reabrir el diálogo todo vuelve a empezar', (
      tester,
    ) async {
      final (cancellation, _) = await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _confirm(tester);
      await _close(tester);

      await _openDialog(tester);

      expect(_enabled(tester, _confirmButton), isTrue);
      expect(_errorText, findsNothing);
      expect(_errorIcon, findsNothing);
      // Y si el plazo sigue vencido, vuelve a deshabilitarse tras otro intento.
      await _confirm(tester);
      expect(cancellation.calls, 2);
      expect(_enabled(tester, _confirmButton), isFalse);
    });
  });

  group('los demás errores no deshabilitan el botón', () {
    for (final failure in [
      StaffCancellationFailure.validation,
      StaffCancellationFailure.unauthenticated,
      StaffCancellationFailure.forbidden,
      StaffCancellationFailure.conflictOfInterest,
      StaffCancellationFailure.other,
      StaffCancellationFailure.notScheduled,
      StaffCancellationFailure.notFound,
    ]) {
      testWidgets('$failure: botón habilitado y se puede cambiar la causa', (
        tester,
      ) async {
        final (cancellation, _) = await _pump(tester, _failure(failure));
        await _openDialog(tester);

        await _confirm(tester);

        expect(find.byType(AlertDialog), findsOneWidget, reason: '$failure');
        expect(_errorText, findsOneWidget, reason: '$failure');
        expect(_enabled(tester, _confirmButton), isTrue, reason: '$failure');
        // Como hasta ahora: al cambiar la causa el mensaje se va.
        await _chooseOther(tester);
        expect(_errorText, findsNothing, reason: '$failure');
        expect(_enabled(tester, _confirmButton), isTrue, reason: '$failure');
        // Y se puede volver a intentar (a pedido del socio, sin motivo que escribir).
        await _chooseMember(tester);
        await _confirm(tester);
        expect(cancellation.calls, 2, reason: '$failure');
      });
    }

    testWidgets('un error de red tampoco: botón habilitado', (tester) async {
      await _pump(tester, const ApiException());
      await _openDialog(tester);

      await _confirm(tester);

      expect(_errorText, findsOneWidget);
      expect(_enabled(tester, _confirmButton), isTrue);
    });

    for (final failure in [
      StaffCancellationFailure.notScheduled,
      StaffCancellationFailure.notFound,
    ]) {
      testWidgets('$failure sigue refrescando la lista', (tester) async {
        final (_, schedules) = await _pump(tester, _failure(failure));
        await _openDialog(tester);
        expect(schedules.searchCalls, 1);

        await _confirm(tester);

        expect(schedules.searchCalls, 2);
        expect(_enabled(tester, _confirmButton), isTrue);
      });
    }

    testWidgets('el error de plazo no refresca la lista', (tester) async {
      final (_, schedules) = await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);

      await _confirm(tester);

      expect(schedules.searchCalls, 1);
    });
  });

  group('accesibilidad del botón deshabilitado', () {
    testWidgets('sigue siendo un botón, ahora sin estado habilitado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _confirm(tester);

      final confirm = tester.getSemantics(_confirmButton);
      expect(confirm.flagsCollection.isButton, isTrue);
      expect(confirm.flagsCollection.isEnabled, Tristate.isFalse);
      expect(confirm.label, contains('Cancelar consulta'));

      final dismiss = tester.getSemantics(_dismissButton);
      expect(dismiss.flagsCollection.isButton, isTrue);
      expect(dismiss.flagsCollection.isEnabled, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('el texto del botón deshabilitado se distingue del fondo', (
      tester,
    ) async {
      await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
      );
      await _openDialog(tester);
      await _confirm(tester);

      // Se mide el color que realmente se dibuja: el del texto del botón,
      // mezclado con el fondo del diálogo (#E7E8EE).
      final label = find.descendant(
        of: _confirmButton,
        matching: find.text('Cancelar consulta'),
      );
      final style = DefaultTextStyle.of(tester.element(label)).style;
      final foreground = style.color!;
      const background = Color(0xFFE7E8EE);
      final blended = Color.alphaBlend(foreground, background);
      // A mano: 50 % de #191C20 sobre #E7E8EE da #808287 (luminancia 0,2230);
      // (0,8088 + 0,05) / (0,2230 + 0,05) = 3,15.
      expect(blended, const Color(0xFF808287));
      final ratio = contrastRatio(blended, background);
      expect(ratio, closeTo(3.15, 0.05));
      expect(ratio, greaterThanOrEqualTo(minimumDisabledContrast));
    });
  });

  group('320 px y texto al doble', () {
    testWidgets('el diálogo con el botón deshabilitado no desborda', (
      tester,
    ) async {
      await _pump(
        tester,
        _failure(StaffCancellationFailure.outsideWindow, _window),
        size: const Size(320, 1800),
        textScale: 2,
      );
      await _openDialog(tester);
      await _confirm(tester);

      expect(tester.takeException(), isNull);
      expect(_enabled(tester, _confirmButton), isFalse);
      expect(_errorIcon, findsOneWidget);
      expect(tester.getRect(_errorText).right, lessThanOrEqualTo(320));
      expect(tester.getRect(_confirmButton).right, lessThanOrEqualTo(320));
      expect(tester.getRect(_dismissButton).left, greaterThanOrEqualTo(0));
    });
  });
}

/// Mínimo para el texto del botón deshabilitado: pensado como un valor
/// razonable (3:1), no el de un botón activo, que es de 4,5:1.
const minimumDisabledContrast = 3.0;
