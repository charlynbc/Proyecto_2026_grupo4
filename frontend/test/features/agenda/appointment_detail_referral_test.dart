import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({required int? referralId}) => Appointment(
  id: 9001,
  status: 'AGENDADA',
  date: DateTime.utc(2026, 11, 25),
  number: 4,
  startMinutes: 600,
  endMinutes: 630,
  doctor: const DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez'),
  specialty: const Specialty(
    id: 3,
    name: 'Cardiología',
    requiresReferral: true,
  ),
  clinic: const Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  referralId: referralId,
  bookedAt: DateTime.parse('2026-11-10T14:15:00-03:00'),
  cancelledAt: null,
  cancellationReason: null,
);

class _HistoryRepository implements AppointmentHistoryRepository {
  _HistoryRepository(this.appointment);

  final Appointment appointment;
  int? requestedId;

  @override
  Future<Appointment> get(int id) async {
    requestedId = id;
    return appointment;
  }

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    throw UnsupportedError('El detalle no debe listar consultas.');
  }
}

Future<void> _pumpDetail(WidgetTester tester, Appointment appointment) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repository = _HistoryRepository(appointment);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: const MaterialApp(home: AppointmentDetailScreen(id: 9001)),
    ),
  );
  await tester.pumpAndSettle();
  expect(repository.requestedId, 9001);
  expect(find.text('Detalle de consulta'), findsOneWidget);
  expect(find.text('Agendada'), findsOneWidget);
}

void _expectDetails() {
  const expectedRows = <(String, String)>[
    ('Estado', 'Agendada'),
    ('Fecha', '25/11/2026'),
    ('Número', '4'),
    ('Horario', '10:00 - 10:30'),
    ('Médico', 'Marta Rodríguez'),
    ('Especialidad', 'Cardiología'),
    ('Consultorio', 'Consultorio 5 (Piso 2)'),
    ('Agendada el', '10/11/2026 14:15'),
  ];
  for (final (label, value) in expectedRows) {
    expect(find.text(label), findsOneWidget);
    final row = find.ancestor(
      of: find.text(label),
      matching: find.byType(ListTile),
    );
    expect(row, findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text(value)),
      findsOneWidget,
      reason: 'La fila $label debe conservar el valor $value.',
    );
  }
}

void main() {
  testWidgets('con pase no muestra la etiqueta ni el identificador interno', (
    tester,
  ) async {
    await _pumpDetail(tester, _appointment(referralId: 7731));

    expect(find.text('Pase'), findsNothing);
    expect(find.text('7731'), findsNothing);
    expect(find.textContaining('7731'), findsNothing);
  });

  testWidgets('con pase conserva las demás filas y sus valores', (
    tester,
  ) async {
    await _pumpDetail(tester, _appointment(referralId: 7731));

    _expectDetails();
  });

  testWidgets('sin pase conserva los detalles y no muestra la fila Pase', (
    tester,
  ) async {
    await _pumpDetail(tester, _appointment(referralId: null));

    expect(find.text('Pase'), findsNothing);
    expect(find.text('7731'), findsNothing);
    _expectDetails();
  });
}
