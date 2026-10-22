import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/providers/agenda_repository_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/agenda_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointments_pending_screen.dart';
import 'package:agenda_medica/features/agenda/screens/availability_screen.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _general = Specialty(
  id: 1,
  name: 'Medicina general',
  requiresReferral: false,
);
const _cardio = Specialty(id: 2, name: 'Cardiología', requiresReferral: true);
const _clinic = Clinic(id: 1, name: 'Consultorio 1', location: 'Piso 2');

AvailableNumber _number(
  int id,
  Specialty s, {
  int doctorId = 4,
  String last = 'Pérez',
}) => AvailableNumber(
  numberId: id,
  shiftId: 7,
  number: id,
  date: DateTime.utc(2026, 11, 5),
  startMinutes: 9 * 60 + 30,
  endMinutes: 9 * 60 + 45,
  doctor: DoctorRef(id: doctorId, firstName: 'Ana', lastName: last),
  specialty: s,
  clinic: _clinic,
);

class _FakeAgenda implements AgendaRepository {
  final queries = <AvailabilityQuery>[];
  final booked = <({int numberId, int? referralId})>[];
  Object? bookError;
  final taken = <int>{};

  @override
  Future<List<AvailableNumber>> listAvailability(AvailabilityQuery q) async {
    queries.add(q);
    final all = [
      _number(11, _general),
      _number(12, _general, doctorId: 5, last: 'Gómez'),
      _number(21, _cardio),
    ];
    return [
      for (final n in all)
        if (n.specialty.id == q.specialtyId &&
            !taken.contains(n.numberId) &&
            (q.doctorId == null || n.doctor.id == q.doctorId))
          n,
    ];
  }

  @override
  Future<Appointment> book({required int numberId, int? referralId}) async {
    booked.add((numberId: numberId, referralId: referralId));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (bookError != null) throw bookError!;
    taken.add(numberId);
    final n = _number(numberId, numberId == 21 ? _cardio : _general);
    return Appointment(
      id: 99,
      status: 'AGENDADA',
      date: n.date,
      number: n.number,
      startMinutes: n.startMinutes,
      endMinutes: n.endMinutes,
      doctor: n.doctor,
      specialty: n.specialty,
      clinic: n.clinic,
      referralId: referralId,
      bookedAt: DateTime.utc(2026, 10, 1, 15),
      cancelledAt: null,
      cancellationReason: null,
    );
  }
}

Future<_FakeAgenda> _pump(
  WidgetTester tester,
  Widget home, {
  _FakeAgenda? agenda,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = agenda ?? _FakeAgenda();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        agendaRepositoryProvider.overrideWith((ref) async => repo),
        specialtiesProvider.overrideWith((ref) async => [_general, _cardio]),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _chooseSpecialty(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const Key('filter-specialty')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

Future<void> _confirm(WidgetTester tester, int numberId) async {
  await tester.tap(find.byKey(Key('book-$numberId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-booking')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pide una especialidad y no consulta hasta elegirla', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    expect(
      find.text('Elegí una especialidad para ver los números disponibles.'),
      findsOneWidget,
    );
    expect(agenda.queries, isEmpty);
    await _unmount(tester);
  });

  testWidgets('al elegir especialidad lista los números con sus datos', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');

    expect(agenda.queries.first.specialtyId, 1);
    expect(agenda.queries.first.doctorId, isNull);
    expect(find.byKey(const Key('number-11')), findsOneWidget);
    expect(find.byKey(const Key('number-12')), findsOneWidget);
    expect(find.byKey(const Key('number-21')), findsNothing);
    expect(find.textContaining('05/11/2026 · 09:30 - 09:45'), findsNWidgets(2));
    expect(find.textContaining('Consultorio 1 (Piso 2)'), findsNWidgets(2));
    await _unmount(tester);
  });

  testWidgets('agenda por numeroId y muestra la consulta real', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');

    await tester.tap(find.byKey(const Key('book-11')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar consulta'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();

    expect(agenda.booked, [(numberId: 11, referralId: null)]);
    expect(find.text('Consulta agendada'), findsOneWidget);
    // 15:00Z es 12:00 en Uruguay.
    expect(find.textContaining('01/10/2026 12:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('number-11')), findsNothing);
    expect(find.byKey(const Key('number-12')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('cancelar la confirmación no agenda', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');
    await tester.tap(find.byKey(const Key('book-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(agenda.booked, isEmpty);
    await _unmount(tester);
  });

  testWidgets('una especialidad con pase exige el número de pase', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Cardiología');

    await tester.tap(find.byKey(const Key('book-21')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá el número de tu pase.'), findsOneWidget);
    expect(agenda.booked, isEmpty);

    await tester.enterText(find.byKey(const Key('referral-id')), '5');
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();
    expect(agenda.booked, [(numberId: 21, referralId: 5)]);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('un número tomado muestra el mensaje y refresca', (tester) async {
    final agenda = _FakeAgenda()
      ..bookError = const BookingException(
        BookingFailure.numberUnavailable,
        'El número ya no está disponible para agendar',
      );
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _chooseSpecialty(tester, 'Medicina general');
    final before = agenda.queries.length;
    agenda.taken.add(11);

    await _confirm(tester, 11);

    expect(
      find.text('El número ya no está disponible para agendar'),
      findsOneWidget,
    );
    expect(agenda.queries.length, greaterThan(before));
    expect(find.byKey(const Key('number-11')), findsNothing);
    await _unmount(tester);
  });

  testWidgets('un límite superado informa sin refrescar', (tester) async {
    final agenda = _FakeAgenda()
      ..bookError = const BookingException(
        BookingFailure.totalLimit,
        'El socio ya tiene el máximo de tres consultas agendadas',
      );
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _chooseSpecialty(tester, 'Medicina general');
    final before = agenda.queries.length;

    await _confirm(tester, 11);

    expect(find.textContaining('máximo de tres consultas'), findsOneWidget);
    expect(agenda.queries.length, before);
    expect(find.byKey(const Key('number-11')), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('mientras agenda deshabilita las demás acciones', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');

    await tester.tap(find.byKey(const Key('book-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pump();
    final other = tester.widget<FilledButton>(find.byKey(const Key('book-12')));
    expect(other.onPressed, isNull);
    await tester.pumpAndSettle();
    expect(agenda.booked, hasLength(1));
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('Mis consultas dice que está pendiente y no muestra datos', (
    tester,
  ) async {
    await _pump(tester, const AppointmentsPendingScreen());
    expect(find.text('Pendiente de implementación'), findsOneWidget);
    expect(find.textContaining('RF-11'), findsOneWidget);
    expect(find.text('Cancelación de consultas'), findsOneWidget);
    expect(find.text('Listado de médicos'), findsOneWidget);
    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancelar consulta'),
    );
    expect(cancel.onPressed, isNull);
    expect(find.byType(ListTile), findsNothing);
  });
}
