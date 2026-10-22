import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointment_detail_screen.dart';
import 'package:agenda_medica/features/agenda/screens/appointments_pending_screen.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _appointment = Appointment(
  id: 9001,
  status: 'NO_ATENDIDA',
  date: DateTime.utc(2026, 10, 20),
  number: 2,
  startMinutes: 560,
  endMinutes: 580,
  doctor: DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez'),
  specialty: Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
  clinic: Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  referralId: null,
  bookedAt: DateTime.parse('2026-10-20T10:12:45-03:00'),
  cancelledAt: null,
  cancellationReason: null,
);

class _HistoryRepository implements AppointmentHistoryRepository {
  _HistoryRepository({this.items = const [], this.total = 0, this.error});

  final List<Appointment> items;
  final int total;
  final Object? error;
  int? requestedId;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    if (error != null) throw error!;
    return AppointmentHistoryPage(
      items: items,
      page: query.page,
      size: query.size,
      total: total,
    );
  }

  @override
  Future<Appointment> get(int id) async {
    requestedId = id;
    if (error != null) throw error!;
    return _appointment;
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  _HistoryRepository repository,
) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        specialtiesProvider.overrideWith(
          (ref) async => const [
            Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
          ],
        ),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra consultas reales, estados y acceso al detalle', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppointmentsPendingScreen(),
      _HistoryRepository(items: [_appointment], total: 1),
    );

    expect(find.text('Mis consultas'), findsOneWidget);
    expect(find.text('Cardiología · No atendida'), findsOneWidget);
    expect(find.textContaining('09:20 - 09:40'), findsOneWidget);
    expect(find.byKey(const Key('appointment-9001')), findsOneWidget);
    expect(find.byKey(const Key('history-next')), findsOneWidget);
  });

  testWidgets('muestra estado vacío y permite reintentar error de conexión', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppointmentsPendingScreen(),
      _HistoryRepository(),
    );
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
  });

  testWidgets('presenta un error de autenticación específico', (tester) async {
    await _pump(
      tester,
      const AppointmentsPendingScreen(),
      _HistoryRepository(
        error: const AppointmentHistoryException(
          AppointmentHistoryFailure.unauthenticated,
          'No autenticado',
        ),
      ),
    );
    expect(
      find.text(
        'Tu sesión venció. Iniciá sesión nuevamente para ver tus consultas.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el detalle muestra la consulta y cancelación deshabilitada', (
    tester,
  ) async {
    final repository = _HistoryRepository();
    await _pump(tester, const AppointmentDetailScreen(id: 9001), repository);

    expect(repository.requestedId, 9001);
    expect(find.text('No atendida'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(
      find.byKey(const Key('cancel-appointment-disabled')),
      findsOneWidget,
    );
    final cancel = tester.widget<OutlinedButton>(
      find.byKey(const Key('cancel-appointment-disabled')),
    );
    expect(cancel.onPressed, isNull);
  });

  testWidgets('el detalle diferencia una consulta inexistente', (tester) async {
    await _pump(
      tester,
      const AppointmentDetailScreen(id: 9001),
      _HistoryRepository(
        error: const AppointmentHistoryException(
          AppointmentHistoryFailure.notFound,
          'No encontrada',
        ),
      ),
    );

    expect(find.text('No se encontró esta consulta.'), findsOneWidget);
  });
}
