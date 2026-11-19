import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/agenda/widgets/appointment_card.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// RF-19: cuando el funcionario cancela por otro motivo, el socio ve el
/// motivo en el detalle de su consulta y no en la tarjeta de Mis consultas
/// (P-30: la tarjeta cancelada es corta a propósito).
Appointment _cancelled({
  String? reason,
  String status = 'CANCELADA_INSTITUCION',
}) => Appointment(
  id: 9001,
  status: status,
  date: DateTime.utc(2026, 11, 25),
  number: 4,
  startMinutes: 600,
  endMinutes: 630,
  doctor: const DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez'),
  specialty: const Specialty(
    id: 3,
    name: 'Cardiología',
    requiresReferral: false,
  ),
  clinic: const Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  referralId: null,
  bookedAt: DateTime.parse('2026-11-10T14:15:00-03:00'),
  cancelledAt: DateTime.parse('2026-11-12T09:03:00-03:00'),
  cancellationReason: reason,
);

class _HistoryRepository implements AppointmentHistoryRepository {
  _HistoryRepository(this.appointment);

  final Appointment appointment;

  @override
  Future<Appointment> get(int id) async => appointment;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    throw UnsupportedError('El detalle no debe listar consultas.');
  }
}

Future<void> _pumpDetail(WidgetTester tester, Appointment appointment) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => _HistoryRepository(appointment),
        ),
      ],
      child: const MaterialApp(home: AppointmentDetailScreen(id: 9001)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el detalle muestra el motivo de una cancelación institucional', (
    tester,
  ) async {
    await _pumpDetail(tester, _cancelled(reason: 'Se rompió el equipo'));

    expect(find.text('Cancelada por la institución'), findsOneWidget);
    expect(find.text('Motivo de cancelación'), findsOneWidget);
    expect(find.text('Se rompió el equipo'), findsOneWidget);
  });

  testWidgets('el detalle de una cancelación a pedido del socio no tiene '
      'motivo', (tester) async {
    await _pumpDetail(tester, _cancelled(status: 'CANCELADA_SOCIO'));

    expect(find.text('Cancelada por el socio'), findsOneWidget);
    expect(find.text('Motivo de cancelación'), findsNothing);
  });

  testWidgets('la tarjeta de Mis consultas no muestra el motivo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentCard(
            appointment: _cancelled(reason: 'Se rompió el equipo'),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('appointment-9001')), findsOneWidget);
    expect(find.textContaining('Se rompió el equipo'), findsNothing);
    expect(find.textContaining('Motivo'), findsNothing);
  });
}
