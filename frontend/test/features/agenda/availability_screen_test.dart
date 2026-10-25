import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/models/referral.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_page.dart';
import 'package:agenda_medica/features/agenda/models/appointment_history_query.dart';
import 'package:agenda_medica/features/agenda/providers/agenda_repository_provider.dart';
import 'package:agenda_medica/features/agenda/providers/appointment_history_provider.dart';
import 'package:agenda_medica/features/agenda/repositories/agenda_repository.dart';
import 'package:agenda_medica/features/agenda/repositories/appointment_history_repository.dart';
import 'package:agenda_medica/features/agenda/screens/appointments_pending_screen.dart';
import 'package:agenda_medica/features/agenda/screens/availability_screen.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/especialidades/providers/specialties_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/load_roboto.dart';

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

  /// Los pases que devuelve `listReferrals`; vacía por defecto.
  final referrals = <Referral>[];

  @override
  Future<List<Referral>> listReferrals() async => List.of(referrals);

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

class _FakeHistory implements AppointmentHistoryRepository {
  int listCalls = 0;

  @override
  Future<AppointmentHistoryPage> list(AppointmentHistoryQuery query) async {
    listCalls++;
    return AppointmentHistoryPage(
      items: const [],
      page: query.page,
      size: query.size,
      total: 0,
    );
  }

  @override
  Future<Appointment> get(int id) async =>
      throw const AppointmentHistoryException(
        AppointmentHistoryFailure.notFound,
      );
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
        appointmentHistoryRepositoryProvider.overrideWith(
          (ref) async => _FakeHistory(),
        ),
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

  testWidgets('la confirmación de una consulta con pase no muestra el pase', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Cardiología');

    await tester.tap(find.byKey(const Key('book-21')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('referral-id')), '5');
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();

    // Se agendó con el pase 5: el aviso lo usa pero no se lo muestra al socio.
    expect(agenda.booked, [(numberId: 21, referralId: 5)]);
    expect(find.text('Consulta agendada'), findsOneWidget);
    final dialog = find.byType(AlertDialog);
    Finder inDialog(String text) =>
        find.descendant(of: dialog, matching: find.textContaining(text));
    expect(inDialog('Estado: Agendada'), findsOneWidget);
    expect(inDialog('Especialidad: Cardiología'), findsOneWidget);
    expect(inDialog('Médico: Ana Pérez'), findsOneWidget);
    expect(inDialog('Horario: 09:30 - 09:45'), findsOneWidget);
    expect(inDialog('Pase'), findsNothing);

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

  testWidgets(
    'Mis consultas muestra el estado real vacío sin datos ficticios',
    (tester) async {
      await _pump(tester, const AppointmentsPendingScreen());
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      expect(find.text('Pendiente de implementación'), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    },
  );

  testWidgets('después de agendar permite abrir Mis consultas actualizado', (
    tester,
  ) async {
    final agenda = _FakeAgenda();
    final history = _FakeHistory();
    final router = GoRouter(
      initialLocation: kAvailabilityPath,
      routes: [
        GoRoute(
          path: kAvailabilityPath,
          builder: (context, state) => const AvailabilityScreen(),
        ),
        GoRoute(
          path: kAppointmentsPath,
          builder: (context, state) => const AppointmentsPendingScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agendaRepositoryProvider.overrideWith((ref) async => agenda),
          appointmentHistoryRepositoryProvider.overrideWith(
            (ref) async => history,
          ),
          specialtiesProvider.overrideWith((ref) async => [_general, _cardio]),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await _chooseSpecialty(tester, 'Medicina general');
    await _confirm(tester, 11);

    await tester.tap(find.byKey(const Key('booked-view-appointments')));
    await tester.pumpAndSettle();

    expect(find.text('Mis consultas'), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(history.listCalls, 1);
  });

  // RF-09: la fecha puede estar a no más de 30 días. El calendario de los dos
  // campos empieza hoy (Uruguay) y termina 30 días después.
  for (final (label, tooltip) in [
    ('Desde', 'Elegir la fecha desde'),
    ('Hasta', 'Elegir la fecha hasta'),
  ]) {
    testWidgets('el calendario de "$label" termina a los 30 días', (
      tester,
    ) async {
      await _pump(tester, const AvailabilityScreen());
      final today = UruguayTime.today();

      await tester.tap(find.byTooltip(tooltip));
      await tester.pumpAndSettle();

      final calendar = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      expect(calendar.firstDate, DateTime(today.year, today.month, today.day));
      expect(
        calendar.lastDate,
        DateTime(today.year, today.month, today.day + 30),
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await _unmount(tester);
    });
  }

  testWidgets('"Requiere pase" aparece en el número de una especialidad con '
      'pase', (tester) async {
    await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Cardiología');

    expect(
      find.descendant(
        of: find.byKey(const Key('number-21')),
        matching: find.text('Requiere pase'),
      ),
      findsOneWidget,
    );
    await _unmount(tester);
  });

  testWidgets('"Requiere pase" no aparece en una especialidad sin pase', (
    tester,
  ) async {
    await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');

    expect(find.byKey(const Key('number-11')), findsOneWidget);
    expect(find.text('Requiere pase'), findsNothing);
    await _unmount(tester);
  });

  // Van al final: Roboto se carga una sola vez por archivo y dejaría de ser
  // Ahem para los tests que vengan después. Con Roboto el texto mide como en
  // un celular; Ahem ensancha todo y daría desbordes que no existen.
  group('diálogos de agendar en pantallas chicas (con Roboto)', () {
    setUpAll(loadRoboto);

    testWidgets('"Confirmar consulta" con pase y el teclado abierto, a '
        '360x640', (tester) async {
      await _pump(tester, const AvailabilityScreen());
      tester.view.physicalSize = const Size(360, 640);
      await _chooseSpecialty(tester, 'Cardiología');
      final book = find.byKey(const Key('book-21'));
      await tester.ensureVisible(book);
      await tester.pumpAndSettle();
      await tester.tap(book);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('referral-id')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final confirm = find.byKey(const Key('confirm-booking'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Ingresá el número de tu pase.'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('"Confirmar consulta" con pase, a 360x360', (tester) async {
      await _pump(tester, const AvailabilityScreen());
      tester.view.physicalSize = const Size(360, 360);
      await _chooseSpecialty(tester, 'Cardiología');
      final book = find.byKey(const Key('book-21'));
      await tester.ensureVisible(book);
      await tester.pumpAndSettle();
      await tester.tap(book);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final confirm = find.byKey(const Key('confirm-booking'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text('Ingresá el número de tu pase.'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('"Consulta agendada", a 360x360', (tester) async {
      await _pump(tester, const AvailabilityScreen());
      tester.view.physicalSize = const Size(360, 360);
      await _chooseSpecialty(tester, 'Medicina general');
      final book = find.byKey(const Key('book-11'));
      await tester.ensureVisible(book);
      await tester.pumpAndSettle();
      await tester.tap(book);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-booking')));
      await tester.pumpAndSettle();
      expect(find.text('Consulta agendada'), findsOneWidget);

      expect(tester.takeException(), isNull);
      final ok = find.byKey(const Key('booked-ok'));
      await tester.ensureVisible(ok);
      await tester.tap(ok);
      await tester.pumpAndSettle();
      expect(find.text('Consulta agendada'), findsNothing);
      await _unmount(tester);
    });
  });
}
