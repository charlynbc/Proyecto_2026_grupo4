import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/widgets/appointment_card.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _marta = DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez');

/// Una consulta de prueba: Cardiología con Marta Rodríguez en el
/// Consultorio 5, el 20/10/2026 de 09:20 a 09:40. Las canceladas llevan
/// fecha de cancelación.
Appointment _appointment({
  int id = 9001,
  int number = 2,
  String status = 'AGENDADA',
  DoctorRef? doctor,
}) => Appointment(
  id: id,
  status: status,
  date: DateTime.utc(2026, 10, 20),
  number: number,
  startMinutes: 560,
  endMinutes: 580,
  doctor: doctor ?? _marta,
  specialty: Specialty(id: 3, name: 'Cardiología', requiresReferral: true),
  clinic: Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2'),
  referralId: null,
  bookedAt: DateTime.utc(2026, 10, 14, 13, 12),
  cancelledAt: status.startsWith('CANCELADA')
      ? DateTime.utc(2026, 10, 18, 15)
      : null,
  cancellationReason: null,
);

Future<void> _pumpCard(WidgetTester tester, Appointment appointment) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: AppointmentCard(appointment: appointment)),
    ),
  );
}

void main() {
  testWidgets('conserva la clave, el título y la fecha con el horario', (
    tester,
  ) async {
    await _pumpCard(tester, _appointment());

    expect(find.byKey(const Key('appointment-9001')), findsOneWidget);
    expect(find.text('Cardiología · Agendada'), findsOneWidget);
    expect(find.textContaining('20/10/2026 · 09:20 - 09:40'), findsOneWidget);
  });

  testWidgets('al tocarla llama a onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppointmentCard(
            appointment: _appointment(),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('appointment-9001')));

    expect(taps, 1);
  });

  group('identificador de la consulta (RF-11)', () {
    testWidgets('una agendada muestra el número y no el ID', (tester) async {
      await _pumpCard(tester, _appointment(id: 123, number: 4));

      expect(
        find.textContaining('Marta Rodríguez · Consultorio 5 · Número 4'),
        findsOneWidget,
      );
    });

    testWidgets('una atendida muestra el número y no el ID', (tester) async {
      await _pumpCard(tester, _appointment(status: 'ATENDIDA'));

      expect(find.textContaining('Número 2'), findsOneWidget);
      expect(find.textContaining('ID'), findsNothing);
    });

    testWidgets('una agendada con id 1 y número 2 no muestra el ID', (
      tester,
    ) async {
      await _pumpCard(tester, _appointment(id: 1, number: 2));

      expect(find.textContaining('Número 2'), findsOneWidget);
      expect(find.textContaining('ID'), findsNothing);
      expect(find.text('000001'), findsNothing);
      expect(find.textContaining('000001'), findsNothing);
    });

    testWidgets('con id 9001 y número 4 el ID no aparece en ningún formato', (
      tester,
    ) async {
      await _pumpCard(tester, _appointment(id: 9001, number: 4));

      expect(find.textContaining('Número 4'), findsOneWidget);
      expect(find.textContaining('009001'), findsNothing);
      expect(find.textContaining('9001'), findsNothing);
    });

    testWidgets('el resto de los datos sigue apareciendo, sin nada más', (
      tester,
    ) async {
      await _pumpCard(tester, _appointment(id: 9001, number: 2));

      expect(find.text('Cardiología · Agendada'), findsOneWidget);
      expect(
        find.text(
          '20/10/2026 · 09:20 - 09:40\n'
          'Marta Rodríguez · Consultorio 5 · Número 2',
        ),
        findsOneWidget,
      );
    });

    for (final status in ['CANCELADA_SOCIO', 'CANCELADA_INSTITUCION']) {
      testWidgets('una $status no muestra ni el número ni el ID', (
        tester,
      ) async {
        await _pumpCard(tester, _appointment(status: status));

        expect(
          find.textContaining('Marta Rodríguez · Consultorio 5'),
          findsOneWidget,
        );
        expect(find.textContaining('ID'), findsNothing);
        expect(find.textContaining('Número'), findsNothing);
      });
    }

    testWidgets('a 360 px con un médico de nombre largo el texto salta de '
        'línea sin desbordar', (tester) async {
      final longDoctor = DoctorRef(
        id: 17,
        firstName: 'María Fernanda de los Ángeles',
        lastName: 'Rodríguez Fernández de la Cuesta',
      );
      final text = find.textContaining('Rodríguez Fernández de la Cuesta');

      await _pumpCard(tester, _appointment(doctor: longDoctor));
      final wideHeight = tester.getSize(text).height;

      tester.view.physicalSize = const Size(360, 1800);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(text).height, greaterThan(wideHeight));
    });
  });
}
