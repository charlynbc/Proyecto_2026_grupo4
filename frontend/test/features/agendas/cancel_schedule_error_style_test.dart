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

/// El error del diálogo de cancelar se ve como error: color de error del tema,
/// un ícono y región viva para el lector de pantalla. El texto y el
/// comportamiento (diálogo abierto, botón habilitado) no cambian.

const _message =
    'La cancelación debe solicitarse con al menos dos horas de anticipación.';

class _Schedules implements ScheduleRepository {
  _Schedules(this.entry);

  final ScheduleEntry entry;

  @override
  Future<SchedulePage> search(ScheduleFilters filters) async =>
      SchedulePage(items: [entry], page: 0, size: 20, total: 1);
}

class _Cancellation implements StaffCancellationRepository {
  int calls = 0;

  @override
  Future<StaffCancellationResult> cancel(int id, {String? reason}) async {
    calls++;
    throw const StaffCancellationException(
      StaffCancellationFailure.outsideWindow,
      _message,
    );
  }
}

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

Future<_Cancellation> _pump(
  WidgetTester tester, {
  Size size = const Size(1300, 1800),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final cancellation = _Cancellation();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        scheduleRepositoryProvider.overrideWith(
          (ref) async => _Schedules(_entry),
        ),
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
  return cancellation;
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

final _errorText = find.byKey(const Key('cancel-schedule-error'));
final _errorIcon = find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byIcon(Icons.error_outline),
);

void main() {
  group('el error del diálogo se ve como error', () {
    // Colores del tema de la app, escritos a mano: error #BA1A1A, fondo del
    // diálogo #E7E8EE y texto del diálogo #191C20 (el que heredan los textos
    // sin estilo propio).
    // Luminancias: error 0,1125; fondo 0,8088. Contraste
    // (0,8088 + 0,05) / (0,1125 + 0,05) = 5,28.
    const error = Color(0xFFBA1A1A);
    const dialogBackground = Color(0xFFE7E8EE);
    const infoColor = Color(0xFF191C20);

    testWidgets('el texto va en el color de error del tema', (tester) async {
      await _pump(tester);
      await _openDialog(tester);
      await _confirm(tester);

      expect(tester.widget<Text>(_errorText).style?.color, error);
    });

    testWidgets('lleva un ícono de error del mismo color, antes del texto', (
      tester,
    ) async {
      await _pump(tester);
      await _openDialog(tester);
      await _confirm(tester);

      expect(_errorIcon, findsOneWidget);
      final icon = tester.widget<Icon>(_errorIcon);
      expect(icon.color, error);
      expect(icon.size, 20);
      expect(icon.semanticLabel, isNull);
      // En el mismo renglón, a la izquierda del texto.
      expect(
        tester.getRect(_errorIcon).right,
        lessThanOrEqualTo(tester.getRect(_errorText).left),
      );
      expect(
        tester.getRect(_errorIcon).center.dy,
        closeTo(tester.getRect(_errorText).top + 10, 12),
      );
    });

    testWidgets('el texto y el ícono forman una región viva', (tester) async {
      await _pump(tester);
      await _openDialog(tester);
      await _confirm(tester);

      final live = find.ancestor(
        of: _errorText,
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.liveRegion == true,
        ),
      );
      expect(live, findsOneWidget);
      expect(
        find.descendant(of: live, matching: find.byIcon(Icons.error_outline)),
        findsOneWidget,
      );
      expect(find.descendant(of: live, matching: _errorText), findsOneWidget);
    });

    testWidgets(
      'el rojo sobre el fondo del diálogo contrasta 5,28 (mínimo 4,5)',
      (tester) async {
        await _pump(tester);
        await _openDialog(tester);
        await _confirm(tester);

        final background = tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(AlertDialog),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color!;
        expect(background, dialogBackground);
        final ratio = contrastRatio(
          tester.widget<Text>(_errorText).style!.color!,
          background,
        );
        expect(ratio, closeTo(5.28, 0.01));
        expect(ratio, greaterThanOrEqualTo(4.5));
      },
    );

    testWidgets('el texto no cambia y el diálogo sigue abierto con el botón '
        'habilitado', (tester) async {
      final cancellation = await _pump(tester);
      await _openDialog(tester);
      await _confirm(tester);

      expect(tester.widget<Text>(_errorText).data, _message);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('confirm-cancel-schedule')),
            )
            .onPressed,
        isNotNull,
      );
      // Si se vuelve a apretar, vuelve a pedir lo mismo.
      await _confirm(tester);
      expect(cancellation.calls, 2);
      expect(tester.widget<Text>(_errorText).data, _message);
    });

    testWidgets('sin error no hay ícono ni mensaje', (tester) async {
      await _pump(tester);
      await _openDialog(tester);

      expect(_errorText, findsNothing);
      expect(_errorIcon, findsNothing);
    });

    testWidgets('al cambiar la causa el error y su ícono desaparecen', (
      tester,
    ) async {
      await _pump(tester);
      await _openDialog(tester);
      await _confirm(tester);
      expect(_errorIcon, findsOneWidget);

      await tester.tap(find.byKey(const Key('cancel-cause-other')));
      await tester.pump();

      expect(_errorText, findsNothing);
      expect(_errorIcon, findsNothing);
    });

    testWidgets('el texto informativo conserva su estilo, sin color de error', (
      tester,
    ) async {
      await _pump(tester);
      await _openDialog(tester);
      await _confirm(tester);

      const info =
          'La cancelación es a pedido del socio y se le avisa por notificación.';
      final finder = find.text(info);
      expect(tester.widget<Text>(finder).style, isNull);
      expect(
        DefaultTextStyle.of(tester.element(finder)).style.color,
        infoColor,
      );
      expect(
        DefaultTextStyle.of(tester.element(finder)).style.color,
        isNot(error),
      );

      await tester.tap(find.byKey(const Key('cancel-cause-other')));
      await tester.pump();
      final other = find.text(
        'El socio va a ver el motivo en el detalle de su consulta y en la notificación.',
      );
      expect(tester.widget<Text>(other).style, isNull);
      expect(DefaultTextStyle.of(tester.element(other)).style.color, infoColor);
    });

    testWidgets('a 320 px y con el texto al doble no hay desbordes', (
      tester,
    ) async {
      await _pump(tester, size: const Size(320, 1800), textScale: 2);
      await _openDialog(tester);
      await _confirm(tester);

      expect(tester.takeException(), isNull);
      expect(_errorIcon, findsOneWidget);
      expect(tester.getRect(_errorText).right, lessThanOrEqualTo(320));
      expect(tester.getRect(_errorIcon).left, greaterThanOrEqualTo(0));
    });
  });
}
