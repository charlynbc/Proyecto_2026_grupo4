import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_cancellation_provider.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_cancellation_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/agenda/models/cancellation_result.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// El texto exacto que ve el socio cuando el servidor dice cancelable: false.
const String kUnavailableText =
    'Esta consulta ya no se puede cancelar desde la aplicación. '
    'Si no vas a poder asistir, comunicate con la institución.';

const _allStatuses = [
  'AGENDADA',
  'ATENDIDA',
  'CANCELADA_SOCIO',
  'CANCELADA_INSTITUCION',
  'NO_SE_PRESENTO',
  'NO_ASISTIO',
  'NO_ATENDIDA',
];

class _HistoryRepository implements AppointmentHistoryRepository {
  _HistoryRepository(this.appointment);

  final Appointment appointment;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async =>
      AppointmentHistoryPage(
        items: [appointment],
        page: query.page,
        size: query.size,
        total: 1,
      );

  @override
  Future<Appointment> get(int id) async => appointment;
}

class _CancellationRepository implements AppointmentCancellationRepository {
  @override
  Future<CancellationResult> cancel(int id) => throw UnimplementedError();
}

Appointment _appointment({required String status, bool? cancelable}) =>
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
      referralId: null,
      bookedAt: DateTime.parse('2026-10-20T10:12:45-03:00'),
      cancelledAt: null,
      cancellationReason: null,
      cancelable: cancelable,
    );

Future<void> _pump(
  WidgetTester tester,
  Appointment appointment, {
  Size size = const Size(900, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => _HistoryRepository(appointment),
        ),
        appointmentCancellationRepositoryProvider.overrideWith(
          (ref) async => _CancellationRepository(),
        ),
      ],
      child: const MaterialApp(home: AppointmentDetailScreen(id: 9001)),
    ),
  );
  await tester.pumpAndSettle();
}

final _button = find.byKey(const Key('cancel-appointment'));
final _unavailable = find.byKey(const Key('cancel-unavailable'));

void main() {
  group('detalle de una consulta AGENDADA', () {
    testWidgets('con cancelable true ofrece el botón y no el texto', (
      tester,
    ) async {
      await _pump(tester, _appointment(status: 'AGENDADA', cancelable: true));

      expect(_button, findsOneWidget);
      expect(find.text('Cancelar consulta'), findsOneWidget);
      expect(_unavailable, findsNothing);
      expect(find.text(kUnavailableText), findsNothing);
    });

    testWidgets('con cancelable null (backend viejo) ofrece el botón', (
      tester,
    ) async {
      await _pump(tester, _appointment(status: 'AGENDADA'));

      expect(_button, findsOneWidget);
      expect(_unavailable, findsNothing);
      expect(find.text(kUnavailableText), findsNothing);
    });

    testWidgets('con cancelable false no ofrece el botón y dice por qué', (
      tester,
    ) async {
      await _pump(tester, _appointment(status: 'AGENDADA', cancelable: false));

      expect(_button, findsNothing);
      expect(find.text('Cancelar consulta'), findsNothing);
      expect(_unavailable, findsOneWidget);
      expect(tester.widget<Text>(_unavailable).data, kUnavailableText);
    });

    testWidgets('el texto va con el estilo por defecto del tema, sin error', (
      tester,
    ) async {
      await _pump(tester, _appointment(status: 'AGENDADA', cancelable: false));

      final theme = Theme.of(tester.element(_unavailable));
      final text = tester.widget<Text>(_unavailable);

      expect(text.style, theme.textTheme.bodyMedium);
      expect(text.style?.color, isNot(theme.colorScheme.error));
    });
  });

  group('detalle de una consulta que no está AGENDADA', () {
    for (final status in _allStatuses.where((s) => s != 'AGENDADA')) {
      for (final cancelable in <bool?>[false, true, null]) {
        testWidgets('$status con cancelable $cancelable no muestra nada', (
          tester,
        ) async {
          await _pump(
            tester,
            _appointment(status: status, cancelable: cancelable),
          );

          expect(_button, findsNothing, reason: 'boton en $status');
          expect(_unavailable, findsNothing, reason: 'texto en $status');
          expect(find.text(kUnavailableText), findsNothing);
        });
      }
    }
  });
}
