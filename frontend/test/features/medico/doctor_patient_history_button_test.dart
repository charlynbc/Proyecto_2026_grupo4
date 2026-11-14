import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/providers/doctor_agenda_controller.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_shift_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_history_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_result_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_shifts_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _ScriptedRepository implements DoctorShiftRepository {
  _ScriptedRepository(this.numbers);

  final List<DoctorShiftNumber> numbers;

  @override
  Future<List<DoctorShift>> listShifts(String date) async => [_shift()];

  @override
  Future<DoctorShiftNumbers> listNumbers(
    int shiftId, {
    bool? arrived,
    DoctorNumbersOrder order = DoctorNumbersOrder.time,
    bool ascending = true,
  }) async => DoctorShiftNumbers(shiftId: shiftId, items: numbers);
}

DoctorShift _shift() => const DoctorShift(
  id: 7,
  date: '2026-03-09',
  startTime: '09:00',
  endTime: '10:00',
  specialtyName: 'Medicina General',
  clinicName: 'Consultorio 1',
  status: 'ACTIVO',
  numbersCount: 2,
  reservedCount: 1,
);

DoctorShiftNumber _reserved({
  required int number,
  required String status,
  int? patientId = 101,
  DateTime? arrivedAt,
}) => DoctorShiftNumber(
  numberId: number,
  number: number,
  startTime: '09:00',
  endTime: '09:20',
  appointmentId: number,
  appointmentStatus: status,
  patient: DoctorPatient(
    id: patientId,
    ci: '12345678',
    name: 'Ana',
    lastName: 'Pérez',
  ),
  arrivedAt: arrivedAt,
);

DoctorShiftNumber _free() => const DoctorShiftNumber(
  numberId: 12,
  number: 12,
  startTime: '09:20',
  endTime: '09:40',
);

Future<void> _pump(WidgetTester tester, _ScriptedRepository repository) async {
  // Ventana más alta que la de prueba por defecto: el botón del sentido con
  // texto ocupa una línea más en la pantalla.
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/medico/turnos',
    routes: [
      GoRoute(
        path: '/medico/turnos',
        builder: (_, _) => const DoctorShiftsScreen(),
      ),
      GoRoute(
        path: kDoctorResultPath,
        builder: (_, state) =>
            Scaffold(body: Center(child: Text('Resultado: ${state.uri}'))),
      ),
      GoRoute(
        path: kDoctorPatientHistoryPath,
        builder: (_, state) =>
            Scaffold(body: Center(child: Text('Historia: ${state.uri}'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorShiftRepositoryProvider.overrideWith((ref) async => repository),
        doctorPollIntervalProvider.overrideWithValue(
          const Duration(seconds: 3),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('doctor-shift-7')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra la acción de historia con aviso de llegada', (
    tester,
  ) async {
    await _pump(
      tester,
      _ScriptedRepository([
        _reserved(
          number: 10,
          status: 'AGENDADA',
          arrivedAt: DateTime.utc(2026, 3, 9, 12, 5),
        ),
      ]),
    );

    final button = find.byKey(const ValueKey('patient-history-10'));
    expect(button, findsOneWidget);
    expect(tester.widget<IconButton>(button).tooltip, 'Ver historia clínica');
  });

  testWidgets('muestra la acción de historia sin aviso de llegada', (
    tester,
  ) async {
    await _pump(
      tester,
      _ScriptedRepository([_reserved(number: 11, status: 'AGENDADA')]),
    );

    expect(find.byKey(const ValueKey('patient-history-11')), findsOneWidget);
  });

  testWidgets('oculta la acción si el paciente no tiene id', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository([
        _reserved(number: 10, status: 'AGENDADA', patientId: null),
      ]),
    );

    expect(find.byKey(const ValueKey('patient-history-10')), findsNothing);
  });

  testWidgets('oculta la acción para una consulta atendida', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository([_reserved(number: 10, status: 'ATENDIDA')]),
    );

    expect(find.byKey(const ValueKey('patient-history-10')), findsNothing);
  });

  testWidgets('oculta la acción en un número libre', (tester) async {
    await _pump(tester, _ScriptedRepository([_free()]));

    expect(find.byKey(const ValueKey('patient-history-12')), findsNothing);
  });

  testWidgets('navega a la historia del paciente al tocar la acción', (
    tester,
  ) async {
    await _pump(
      tester,
      _ScriptedRepository([_reserved(number: 10, status: 'AGENDADA')]),
    );

    await tester.tap(find.byKey(const ValueKey('patient-history-10')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Historia: /medico/pacientes/101/historia?paciente=Ana%20P%C3%A9rez',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Resultado:'), findsNothing);
  });

  testWidgets('conserva la acción de cancelar junto a la historia', (
    tester,
  ) async {
    await _pump(
      tester,
      _ScriptedRepository([_reserved(number: 10, status: 'AGENDADA')]),
    );

    expect(find.byKey(const ValueKey('cancel-appointment-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('patient-history-10')), findsOneWidget);
  });
}
