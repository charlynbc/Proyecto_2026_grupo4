import 'dart:async';

import 'package:agenda_medica/features/historia_clinica/models/medical_history_entry.dart';
import 'package:agenda_medica/features/medico/providers/doctor_patient_history_provider.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_patient_history_repository.dart';
import 'package:agenda_medica/features/medico/screens/doctor_history_routes.dart';
import 'package:agenda_medica/features/medico/screens/doctor_patient_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/load_roboto.dart';

const _notFoundMessage =
    'No podés ver la historia clínica de este paciente en este momento. '
    'Solo está disponible mientras tengas con él una consulta agendada que '
    'no haya terminado.';

class _StubDoctorPatientHistoryRepository
    implements DoctorPatientHistoryRepository {
  _StubDoctorPatientHistoryRepository({
    this.entries = const [],
    this.error,
    this.errorOnlyFirstCall = false,
    this.pending,
  });

  final List<MedicalHistoryEntry> entries;
  final Object? error;
  final bool errorOnlyFirstCall;
  final Completer<List<MedicalHistoryEntry>>? pending;
  int calls = 0;

  @override
  Future<List<MedicalHistoryEntry>> history(int socioId) async {
    calls++;
    if (error != null && (!errorOnlyFirstCall || calls == 1)) {
      throw error!;
    }
    if (pending != null) return pending!.future;
    return entries;
  }
}

Future<void> _pumpHistoryScreen(
  WidgetTester tester,
  _StubDoctorPatientHistoryRepository repository, {
  String? patientName,
  int socioId = 101,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        doctorPatientHistoryRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
      child: MaterialApp(
        home: DoctorPatientHistoryScreen(
          socioId: socioId,
          patientName: patientName,
        ),
      ),
    ),
  );
}

List<MedicalHistoryEntry> _twoEntries() => [
  MedicalHistoryEntry.fromJson({
    'idAtencion': 5530,
    'fechaAtencion': '2026-10-20',
    'medicoId': 17,
    'medicoNombre': 'Marta',
    'medicoApellido': 'Rodríguez',
    'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
    'afeccion': 'Hipertensión arterial leve',
    'tratamiento': 'Control de dieta y medicación indicada',
    'observaciones': null,
    'pases': [
      {
        'id': 78,
        'especialidad': {'id': 4, 'nombre': 'Nutrición', 'requierePase': true},
        'emitidoEn': '2026-10-20T09:41:00-03:00',
        'venceEl': '2027-01-18',
      },
    ],
  }),
  MedicalHistoryEntry.fromJson({
    'idAtencion': 5000,
    'fechaAtencion': '2026-09-10',
    'medicoId': 18,
    'medicoNombre': 'Laura',
    'medicoApellido': 'Pérez',
    'especialidad': {'id': 5, 'nombre': 'Traumatología', 'requierePase': false},
    'afeccion': 'Dolor lumbar',
    'tratamiento': null,
    'observaciones': null,
    'pases': <Object>[],
  }),
];

void main() {
  test('la ruta codifica el nombre del paciente', () {
    expect(
      doctorPatientHistoryLocation(101, patientName: 'Ana Pérez'),
      '/medico/pacientes/101/historia?paciente=Ana%20P%C3%A9rez',
    );
  });

  test('la ruta no agrega un nombre ausente', () {
    expect(doctorPatientHistoryLocation(101), '/medico/pacientes/101/historia');
  });

  testWidgets('muestra los datos en el orden recibido y omite observaciones', (
    tester,
  ) async {
    await _pumpHistoryScreen(
      tester,
      _StubDoctorPatientHistoryRepository(entries: _twoEntries()),
      patientName: 'Ana Pérez',
    );
    await tester.pumpAndSettle();

    expect(find.text('20/10/2026'), findsOneWidget);
    expect(find.text('Marta Rodríguez'), findsOneWidget);
    expect(find.text('Cardiología'), findsOneWidget);
    expect(find.text('Hipertensión arterial leve'), findsOneWidget);
    expect(find.text('Nutrición'), findsOneWidget);
    expect(find.text('Vence el 18/01/2027'), findsOneWidget);
    expect(find.text('Observaciones'), findsNothing);
    expect(find.text('10/09/2026'), findsOneWidget);
    expect(find.text('Laura Pérez'), findsOneWidget);
    expect(find.text('Traumatología'), findsOneWidget);
    expect(find.text('Dolor lumbar'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Marta Rodríguez')).dy,
      lessThan(tester.getTopLeft(find.text('Laura Pérez')).dy),
    );
  });

  testWidgets('muestra el aviso de solo lectura y el nombre del paciente', (
    tester,
  ) async {
    await _pumpHistoryScreen(
      tester,
      _StubDoctorPatientHistoryRepository(),
      patientName: 'Ana Pérez',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('patient-history-notice')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Solo lectura. Podés ver esta historia mientras tengas una consulta '
        'agendada con el paciente que todavía no haya terminado.',
      ),
      findsOneWidget,
    );
    expect(find.text('Paciente: Ana Pérez'), findsOneWidget);
  });

  testWidgets('la flecha de volver de la barra superior tiene el tooltip '
      '"Volver"', (tester) async {
    await _pumpHistoryScreen(tester, _StubDoctorPatientHistoryRepository());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Volver'), findsOneWidget);
  });

  testWidgets('el aviso usa surfaceContainerHigh del tema, con padding 12 y '
      'borde de 8', (tester) async {
    // Un tema donde cada color de superficie es distinguible a simple vista.
    final scheme = const ColorScheme.light().copyWith(
      surfaceContainerHigh: const Color(0xFFABCDEF),
      surfaceContainerLow: const Color(0xFF123456),
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          doctorPatientHistoryRepositoryProvider.overrideWith(
            (ref) async => _StubDoctorPatientHistoryRepository(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: const DoctorPatientHistoryScreen(socioId: 101),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final notice = tester.widget<Container>(
      find.byKey(const ValueKey('patient-history-notice')),
    );
    final decoration = notice.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFABCDEF));
    expect(decoration.borderRadius, BorderRadius.circular(8));
    expect(notice.padding, const EdgeInsets.all(12));
  });

  testWidgets('no muestra la etiqueta de paciente cuando no hay nombre', (
    tester,
  ) async {
    await _pumpHistoryScreen(tester, _StubDoctorPatientHistoryRepository());
    await tester.pumpAndSettle();

    expect(find.textContaining('Paciente:'), findsNothing);
  });

  testWidgets('muestra el mensaje cuando la lista está vacía', (tester) async {
    await _pumpHistoryScreen(tester, _StubDoctorPatientHistoryRepository());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('patient-history-empty')), findsOneWidget);
    expect(
      find.text('Este paciente todavía no tiene atenciones registradas.'),
      findsOneWidget,
    );
  });

  testWidgets('reintenta un error notFound y luego muestra la lista', (
    tester,
  ) async {
    final repository = _StubDoctorPatientHistoryRepository(
      entries: _twoEntries(),
      error: const DoctorPatientHistoryException(
        DoctorPatientHistoryFailure.notFound,
        _notFoundMessage,
      ),
      errorOnlyFirstCall: true,
    );
    await _pumpHistoryScreen(tester, repository);
    await tester.pump();
    await tester.pump();

    expect(find.text(_notFoundMessage), findsOneWidget);
    expect(find.byKey(const ValueKey('patient-history-retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('patient-history-retry')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Marta Rodríguez'), findsOneWidget);
  });

  testWidgets('muestra un indicador mientras carga la historia', (
    tester,
  ) async {
    final repository = _StubDoctorPatientHistoryRepository(
      pending: Completer<List<MedicalHistoryEntry>>(),
    );
    await _pumpHistoryScreen(tester, repository);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('pantalla a 320 px con Roboto', () {
    setUpAll(loadRoboto);

    testWidgets('muestra las dos atenciones sin desbordarse', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpHistoryScreen(
        tester,
        _StubDoctorPatientHistoryRepository(entries: _twoEntries()),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
