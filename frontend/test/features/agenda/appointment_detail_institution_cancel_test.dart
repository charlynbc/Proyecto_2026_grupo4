import 'package:agenda_medica/core/theme/app_theme.dart';
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

// Una consulta cancelada por la institución, armada en el propio test: el Fake
// de consultas no tiene ninguna.
Appointment _cancelled({String? reason}) => Appointment(
  id: 9002,
  status: 'CANCELADA_INSTITUCION',
  date: DateTime.utc(2026, 12, 1),
  number: 3,
  startMinutes: 14 * 60,
  endMinutes: 14 * 60 + 30,
  doctor: DoctorRef(id: 1, firstName: 'Carla', lastName: 'Méndez'),
  specialty: Specialty(
    id: 1,
    name: 'Medicina General',
    requiresReferral: false,
  ),
  clinic: Clinic(id: 3, name: 'Consultorio 3', location: 'Piso 1'),
  referralId: null,
  bookedAt: DateTime.utc(2026, 11, 10, 15),
  cancelledAt: DateTime.utc(2026, 11, 17, 19, 43),
  cancellationReason: reason,
);

class _Repository implements AppointmentHistoryRepository {
  _Repository(this.appointment);

  final Appointment appointment;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async =>
      throw UnimplementedError();

  @override
  Future<Appointment> get(int id) async => appointment;
}

Future<void> _open(WidgetTester tester, Appointment appointment) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => _Repository(appointment),
        ),
      ],
      child: MaterialApp(
        theme: appTheme,
        home: AppointmentDetailScreen(id: appointment.id),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('una cancelada por la institución con motivo lo muestra', (
    tester,
  ) async {
    await _open(tester, _cancelled(reason: 'El médico no atiende ese día.'));

    expect(find.text('Cancelada por la institución'), findsOneWidget);
    expect(find.text('Cancelada por el socio'), findsNothing);
    expect(find.text('Motivo de cancelación'), findsOneWidget);
    expect(find.text('El médico no atiende ese día.'), findsOneWidget);
    expect(find.text('01/12/2026'), findsOneWidget);
    expect(find.text('Cancelar consulta'), findsNothing);
  });

  testWidgets('sin motivo no muestra la fila del motivo', (tester) async {
    await _open(tester, _cancelled());

    expect(find.text('Cancelada por la institución'), findsOneWidget);
    expect(find.text('Motivo de cancelación'), findsNothing);
  });
}
