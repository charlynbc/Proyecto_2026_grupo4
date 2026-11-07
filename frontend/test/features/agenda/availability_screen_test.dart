import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/agenda/models/availability_query.dart';
import 'package:agenda_medica/features/agenda/models/available_number.dart';
import 'package:agenda_medica/features/agenda/models/doctor_with_specialties.dart';
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
import 'package:agenda_medica/core/widgets/ui_date_field.dart';
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
const _derm = Specialty(id: 3, name: 'Dermatología', requiresReferral: true);
const _clinic = Clinic(id: 1, name: 'Consultorio 1', location: 'Piso 2');

/// Un pase de [specialty] que vence el [expiresOn] (el número 21 es del
/// 05/11/2026).
Referral _referral(int id, Specialty specialty, DateTime expiresOn) => Referral(
  id: id,
  specialty: specialty,
  issuedAt: DateTime.utc(2026, 10, 1, 12),
  expiresOn: expiresOn,
);

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

// Los médicos del servidor, por apellido y nombre: Gómez (5) ejerce solo
// Medicina general, Pérez (4) ejerce Medicina general y Cardiología, y Silva
// (6) ejerce solo Cardiología y no tiene números libres.
const _generalRef = SpecialtyRef(id: 1, name: 'Medicina general');
const _cardioRef = SpecialtyRef(id: 2, name: 'Cardiología');
const _doctors = [
  DoctorWithSpecialties(
    id: 5,
    firstName: 'Ana',
    lastName: 'Gómez',
    specialties: [_generalRef],
  ),
  DoctorWithSpecialties(
    id: 4,
    firstName: 'Ana',
    lastName: 'Pérez',
    specialties: [_generalRef, _cardioRef],
  ),
  DoctorWithSpecialties(
    id: 6,
    firstName: 'Marta',
    lastName: 'Silva',
    specialties: [_cardioRef],
  ),
];

class _FakeAgenda implements AgendaRepository {
  final queries = <AvailabilityQuery>[];

  /// El `especialidadId` de cada pedido de la lista de médicos.
  final doctorRequests = <int?>[];

  /// Si está, `listDoctors` falla con él.
  Object? doctorsError;

  /// Si está, `listDoctors` espera a que se complete (para ver "cargando").
  Completer<List<DoctorWithSpecialties>>? doctorsGate;
  final booked = <({int numberId, int? referralId})>[];
  Object? bookError;
  final taken = <int>{};

  /// Los pases que devuelve `listReferrals`; vacía por defecto.
  final referrals = <Referral>[];

  /// Si está, `listReferrals` espera a que se complete (para ver "cargando").
  Completer<List<Referral>>? referralsGate;

  /// Si está, `listReferrals` falla con él.
  Object? referralsError;
  int listReferralsCalls = 0;

  @override
  Future<List<Referral>> listReferrals() async {
    listReferralsCalls++;
    final gate = referralsGate;
    if (gate != null) return gate.future;
    if (referralsError != null) throw referralsError!;
    return List.of(referrals);
  }

  @override
  Future<List<DoctorWithSpecialties>> listDoctors({int? specialtyId}) async {
    doctorRequests.add(specialtyId);
    final gate = doctorsGate;
    if (gate != null) return gate.future;
    if (doctorsError != null) throw doctorsError!;
    return [
      for (final d in _doctors)
        if (specialtyId == null || d.attends(specialtyId)) d,
    ];
  }

  @override
  Future<List<AvailableNumber>> listAvailability(AvailabilityQuery q) async {
    queries.add(q);
    final all = [
      _number(11, _general),
      _number(12, _general, doctorId: 5, last: 'Gómez'),
      _number(21, _cardio),
    ];
    final result = [
      for (final n in all)
        if ((q.specialtyId == null || n.specialty.id == q.specialtyId) &&
            !taken.contains(n.numberId) &&
            (q.doctorId == null || n.doctor.id == q.doctorId))
          n,
    ];
    // El servidor ordena; acá solo se respeta el sentido, por numberId.
    return q.direction == SortDirection.desc
        ? result.reversed.toList()
        : result;
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
    // La lista de médicos de Mis consultas pide de a 100 y no cuenta.
    if (query.size != 100) listCalls++;
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

const _searchKey = Key('availability-search-button');
const _emptyHint =
    'Elegí una especialidad o un médico y tocá Buscar para ver los números '
    'disponibles.';
const _noResults = 'No hay números disponibles con estos filtros.';
const _invertedRange =
    'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';

/// Elige la especialidad en el desplegable, sin tocar Buscar.
Future<void> _selectSpecialty(WidgetTester tester, String name) async {
  final field = find.byKey(const Key('filter-specialty'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// Toca Buscar.
Future<void> _search(WidgetTester tester) async {
  final button = find.byKey(_searchKey);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Elige la especialidad y toca Buscar.
Future<void> _chooseSpecialty(WidgetTester tester, String name) async {
  await _selectSpecialty(tester, name);
  await _search(tester);
}

final _doctorDropdown = find.byKey(const Key('filter-doctor'));
final _specialtyDropdown = find.byKey(const Key('filter-specialty'));

DropdownButtonFormField<int?> _doctorField(WidgetTester tester) =>
    tester.widget<DropdownButtonFormField<int?>>(_doctorDropdown);

DropdownButtonFormField<int?> _specialtyField(WidgetTester tester) =>
    tester.widget<DropdownButtonFormField<int?>>(_specialtyDropdown);

/// Los valores de las opciones de un desplegable, en orden; `null` es
/// "Todos".
List<int?> _optionValues(WidgetTester tester, Finder dropdown) => [
  for (final item
      in tester
          .widget<DropdownButton<int?>>(
            find.descendant(
              of: dropdown,
              matching: find.byType(DropdownButton<int?>),
            ),
          )
          .items!)
    item.value,
];

Future<void> _chooseDoctor(WidgetTester tester, String name) async {
  await tester.ensureVisible(_doctorDropdown);
  await tester.pumpAndSettle();
  await tester.tap(_doctorDropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

bool _searchEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(_searchKey)).onPressed != null;

/// Las keys de los números que se ven, de arriba hacia abajo.
List<String> _listedNumbers(WidgetTester tester) => [
  for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
    (tile.key! as ValueKey<String>).value,
];

/// Escribe [text] en el campo de fecha [index] (0 es Desde, 1 es Hasta).
Future<void> _typeDate(WidgetTester tester, int index, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(UiDateField).at(index),
      matching: find.byType(TextField),
    ),
    text,
  );
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

/// Elige Cardiología y abre "Confirmar consulta" del número 21.
Future<void> _openCardioBooking(WidgetTester tester) async {
  await _chooseSpecialty(tester, 'Cardiología');
  final book = find.byKey(const Key('book-21'));
  await tester.ensureVisible(book);
  await tester.pumpAndSettle();
  await tester.tap(book);
  await tester.pumpAndSettle();
}

bool _confirmEnabled(WidgetTester tester) =>
    tester
        .widget<FilledButton>(find.byKey(const Key('confirm-booking')))
        .onPressed !=
    null;

void main() {
  testWidgets('el AppBar muestra Reservar consulta y no Disponibilidad', (
    tester,
  ) async {
    await _pump(tester, const AvailabilityScreen());

    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);
    final title = tester.widget<AppBar>(appBar).title;
    expect(title, isA<Text>());
    expect((title! as Text).data, 'Reservar consulta');
    expect(
      find.descendant(of: appBar, matching: find.text('Reservar consulta')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: appBar, matching: find.text('Disponibilidad')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pide una especialidad y no consulta hasta elegirla', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    expect(find.text(_emptyHint), findsOneWidget);
    expect(agenda.queries, isEmpty);
    await _unmount(tester);
  });

  testWidgets('elegir una especialidad no consulta hasta tocar Buscar', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _selectSpecialty(tester, 'Medicina general');

    expect(agenda.queries, isEmpty);
    expect(find.text(_emptyHint), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await _unmount(tester);
  });

  testWidgets('Buscar está apagado sin especialidad y prendido con ella', (
    tester,
  ) async {
    await _pump(tester, const AvailabilityScreen());
    expect(
      tester.widget<FilledButton>(find.byKey(_searchKey)).onPressed,
      isNull,
    );

    await _selectSpecialty(tester, 'Medicina general');

    expect(
      tester.widget<FilledButton>(find.byKey(_searchKey)).onPressed,
      isNotNull,
    );
    await _unmount(tester);
  });

  testWidgets('Buscar consulta una vez con la especialidad elegida', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _selectSpecialty(tester, 'Medicina general');
    await _search(tester);

    expect(agenda.queries, hasLength(1));
    expect(agenda.queries.single.specialtyId, 1);
    expect(agenda.queries.single.doctorId, isNull);
    expect(find.text(_emptyHint), findsNothing);
    expect(_listedNumbers(tester), ['number-11', 'number-12']);
    await _unmount(tester);
  });

  testWidgets('cambiar la especialidad no consulta: la lista queda hasta el '
      'próximo Buscar', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Cardiología');
    expect(agenda.queries, hasLength(1));
    expect(_listedNumbers(tester), ['number-21']);

    await _selectSpecialty(tester, 'Medicina general');

    expect(agenda.queries, hasLength(1));
    expect(_listedNumbers(tester), ['number-21']);

    await _search(tester);

    expect(agenda.queries, hasLength(2));
    expect(agenda.queries.last.specialtyId, 1);
    expect(_listedNumbers(tester), ['number-11', 'number-12']);
    await _unmount(tester);
  });

  testWidgets('elegir un médico no consulta y Buscar aplica el filtro', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');
    expect(agenda.queries, hasLength(1));
    expect(_doctorField(tester).onChanged, isNotNull);

    await _chooseDoctor(tester, 'Gómez, Ana');

    expect(agenda.queries, hasLength(1));
    expect(_listedNumbers(tester), ['number-11', 'number-12']);

    await _search(tester);

    expect(agenda.queries, hasLength(2));
    expect(agenda.queries.last.specialtyId, 1);
    expect(agenda.queries.last.doctorId, 5);
    expect(_listedNumbers(tester), ['number-12']);
    await _unmount(tester);
  });

  testWidgets('al abrir, médico y especialidad están habilitados y se pidió '
      'la lista de médicos una vez', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());

    expect(_specialtyField(tester).onChanged, isNotNull);
    expect(_doctorField(tester).onChanged, isNotNull);
    expect(_optionValues(tester, _doctorDropdown), [null, 5, 4, 6]);
    expect(_optionValues(tester, _specialtyDropdown), [null, 1, 2]);
    expect(agenda.doctorRequests, [null]);
    expect(agenda.queries, isEmpty);
    await _unmount(tester);
  });

  testWidgets('solo con médico: Buscar queda habilitado y consulta sin '
      'especialidad', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    expect(_searchEnabled(tester), isFalse);

    await _chooseDoctor(tester, 'Gómez, Ana');

    expect(_searchEnabled(tester), isTrue);
    expect(agenda.queries, isEmpty);
    // Las especialidades que ofrece son solo las de ese médico.
    expect(_optionValues(tester, _specialtyDropdown), [null, 1]);

    await _search(tester);

    expect(agenda.queries, hasLength(1));
    expect(agenda.queries.single.specialtyId, isNull);
    expect(agenda.queries.single.doctorId, 5);
    expect(
      agenda.queries.single.toQueryParameters().containsKey('especialidadId'),
      isFalse,
    );
    expect(_listedNumbers(tester), ['number-12']);
    await _unmount(tester);
  });

  testWidgets('con médico y especialidad consulta con los dos', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _selectSpecialty(tester, 'Medicina general');
    await _chooseDoctor(tester, 'Pérez, Ana');
    await _search(tester);

    expect(agenda.queries, hasLength(1));
    expect(agenda.queries.single.specialtyId, 1);
    expect(agenda.queries.single.doctorId, 4);
    expect(_listedNumbers(tester), ['number-11']);
    await _unmount(tester);
  });

  testWidgets('sin médico ni especialidad Buscar está apagado y se ve la '
      'ayuda', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());

    expect(_searchEnabled(tester), isFalse);
    expect(find.text(_emptyHint), findsOneWidget);

    await _selectSpecialty(tester, 'Medicina general');
    expect(_searchEnabled(tester), isTrue);

    // Volver a "Todos" deja otra vez sin filtros.
    await tester.tap(_specialtyDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();

    expect(_searchEnabled(tester), isFalse);
    expect(find.text(_emptyHint), findsOneWidget);
    expect(agenda.queries, isEmpty);
    await _unmount(tester);
  });

  testWidgets('elegir una especialidad deja solo los médicos que la '
      'atienden, sin otra llamada', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());

    await _selectSpecialty(tester, 'Medicina general');
    expect(_optionValues(tester, _doctorDropdown), [null, 5, 4]);

    await _selectSpecialty(tester, 'Cardiología');
    expect(_optionValues(tester, _doctorDropdown), [null, 4, 6]);

    expect(agenda.doctorRequests, [null]);
    await _unmount(tester);
  });

  testWidgets('elegir un médico deja solo sus especialidades', (tester) async {
    await _pump(tester, const AvailabilityScreen());

    await _chooseDoctor(tester, 'Silva, Marta');
    expect(_optionValues(tester, _specialtyDropdown), [null, 2]);

    await _chooseDoctor(tester, 'Pérez, Ana');
    expect(_optionValues(tester, _specialtyDropdown), [null, 1, 2]);
    await _unmount(tester);
  });

  // Con el médico elegido el desplegable de especialidad ya no ofrece las que
  // no atiende; esto cubre la regla por si el cambio llegara por otro camino.
  testWidgets('una especialidad que el médico elegido no atiende lo '
      'reinicia', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseDoctor(tester, 'Gómez, Ana');
    expect(find.text('Gómez, Ana'), findsOneWidget);

    _specialtyField(tester).onChanged!(2);
    await tester.pumpAndSettle();

    expect(find.text('Gómez, Ana'), findsNothing);
    expect(_doctorField(tester).initialValue, isNull);
    await _search(tester);

    expect(agenda.queries.single.specialtyId, 2);
    expect(agenda.queries.single.doctorId, isNull);
    expect(_listedNumbers(tester), ['number-21']);
    await _unmount(tester);
  });

  testWidgets('con médico solo, Orden y Sentido siguen al instante', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseDoctor(tester, 'Pérez, Ana');
    await tester.tap(find.byKey(const Key('filter-direction')));
    await tester.pumpAndSettle();
    expect(agenda.queries, isEmpty);

    await _search(tester);
    expect(agenda.queries, hasLength(1));
    expect(agenda.queries.last.direction, SortDirection.desc);
    expect(_listedNumbers(tester), ['number-21', 'number-11']);

    await tester.tap(find.byKey(const Key('filter-direction')));
    await tester.pumpAndSettle();

    expect(agenda.queries, hasLength(2));
    expect(agenda.queries.last.specialtyId, isNull);
    expect(agenda.queries.last.doctorId, 4);
    expect(agenda.queries.last.direction, SortDirection.asc);
    expect(_listedNumbers(tester), ['number-11', 'number-21']);
    await _unmount(tester);
  });

  testWidgets('un médico sin números libres se puede elegir y da la lista '
      'vacía', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseDoctor(tester, 'Silva, Marta');
    await _search(tester);

    expect(agenda.queries.single.doctorId, 6);
    expect(find.text(_noResults), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    await _unmount(tester);
  });

  // Debajo de los filtros se ve una sola cosa: la ayuda (sin búsqueda
  // aplicada), el aviso de lista vacía o la lista. Nunca dos a la vez.
  group('un solo mensaje debajo de los filtros', () {
    Future<void> chooseAll(WidgetTester tester, Finder dropdown) async {
      await tester.ensureVisible(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos').last);
      await tester.pumpAndSettle();
    }

    Future<void> clearFilters(WidgetTester tester) async {
      final clear = find.text('Limpiar filtros');
      await tester.ensureVisible(clear);
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();
    }

    void expectOnlyHint() {
      expect(find.text(_emptyHint), findsOneWidget);
      expect(find.text(_noResults), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    }

    testWidgets('a) recién abierta: solo la ayuda', (tester) async {
      await _pump(tester, const AvailabilityScreen());

      expectOnlyHint();
      await _unmount(tester);
    });

    testWidgets('b) búsqueda vacía y Limpiar filtros: solo la ayuda', (
      tester,
    ) async {
      await _pump(tester, const AvailabilityScreen());
      await _chooseDoctor(tester, 'Silva, Marta');
      await _search(tester);
      expect(find.text(_noResults), findsOneWidget);

      await clearFilters(tester);

      expectOnlyHint();
      await _unmount(tester);
    });

    testWidgets('b) búsqueda vacía y médico en Todos a mano: solo la ayuda', (
      tester,
    ) async {
      final agenda = await _pump(tester, const AvailabilityScreen());
      await _chooseDoctor(tester, 'Silva, Marta');
      await _search(tester);
      expect(find.text(_noResults), findsOneWidget);

      await chooseAll(tester, _doctorDropdown);

      expect(_searchEnabled(tester), isFalse);
      expectOnlyHint();
      expect(agenda.queries, hasLength(1));
      await _unmount(tester);
    });

    testWidgets('c) con resultados y Limpiar filtros: solo la ayuda', (
      tester,
    ) async {
      await _pump(tester, const AvailabilityScreen());
      await _chooseSpecialty(tester, 'Medicina general');
      expect(_listedNumbers(tester), ['number-11', 'number-12']);

      await clearFilters(tester);

      expectOnlyHint();
      await _unmount(tester);
    });

    testWidgets('c) con resultados y especialidad en Todos a mano: solo la '
        'ayuda', (tester) async {
      await _pump(tester, const AvailabilityScreen());
      await _chooseSpecialty(tester, 'Medicina general');
      expect(_listedNumbers(tester), ['number-11', 'number-12']);

      await chooseAll(tester, _specialtyDropdown);

      expect(_searchEnabled(tester), isFalse);
      expectOnlyHint();
      await _unmount(tester);
    });

    testWidgets('d) con la lista de médicos cargando: solo la ayuda', (
      tester,
    ) async {
      final agenda = _FakeAgenda()
        ..doctorsGate = Completer<List<DoctorWithSpecialties>>();
      await _pump(tester, const AvailabilityScreen(), agenda: agenda);

      expect(find.text('Cargando médicos'), findsOneWidget);
      expectOnlyHint();

      agenda.doctorsGate!.complete(const []);
      await tester.pumpAndSettle();
      await _unmount(tester);
    });

    testWidgets('d) con la lista de médicos fallida: solo la ayuda', (
      tester,
    ) async {
      final agenda = _FakeAgenda()
        ..doctorsError = const ApiException('No pudimos cargar los médicos.');
      await _pump(tester, const AvailabilityScreen(), agenda: agenda);

      expect(find.text('No pudimos cargar los médicos.'), findsOneWidget);
      expectOnlyHint();
      await _unmount(tester);
    });

    testWidgets('búsqueda vacía: solo el aviso de lista vacía', (tester) async {
      await _pump(tester, const AvailabilityScreen());
      await _chooseDoctor(tester, 'Silva, Marta');
      await _search(tester);

      expect(find.text(_noResults), findsOneWidget);
      expect(find.text(_emptyHint), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      await _unmount(tester);
    });

    testWidgets('con resultados: ni la ayuda ni el aviso de lista vacía', (
      tester,
    ) async {
      await _pump(tester, const AvailabilityScreen());
      await _chooseSpecialty(tester, 'Medicina general');

      expect(_listedNumbers(tester), ['number-11', 'number-12']);
      expect(find.text(_emptyHint), findsNothing);
      expect(find.text(_noResults), findsNothing);
      await _unmount(tester);
    });

    testWidgets('cambiar un filtro sin tocar Buscar no cambia lo que se ve', (
      tester,
    ) async {
      final agenda = await _pump(tester, const AvailabilityScreen());
      await _chooseDoctor(tester, 'Silva, Marta');
      await _search(tester);
      expect(find.text(_noResults), findsOneWidget);

      await _chooseDoctor(tester, 'Gómez, Ana');

      expect(find.text(_noResults), findsOneWidget);
      expect(find.text(_emptyHint), findsNothing);
      expect(agenda.queries, hasLength(1));
      await _unmount(tester);
    });

    testWidgets('volver a elegir un filtro tras quedar sin ninguno no trae '
        'de vuelta la búsqueda anterior', (tester) async {
      final agenda = await _pump(tester, const AvailabilityScreen());
      await _chooseSpecialty(tester, 'Medicina general');
      await chooseAll(tester, _specialtyDropdown);
      expectOnlyHint();

      await _chooseDoctor(tester, 'Gómez, Ana');

      expectOnlyHint();
      expect(agenda.queries, hasLength(1));
      await _unmount(tester);
    });
  });

  testWidgets('Limpiar filtros deja médico y especialidad en Todos', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _selectSpecialty(tester, 'Medicina general');
    await _chooseDoctor(tester, 'Gómez, Ana');
    await _search(tester);
    expect(_listedNumbers(tester), ['number-12']);

    final clear = find.text('Limpiar filtros');
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(_specialtyField(tester).initialValue, isNull);
    expect(_doctorField(tester).initialValue, isNull);
    expect(find.text('Gómez, Ana'), findsNothing);
    expect(_optionValues(tester, _doctorDropdown), [null, 5, 4, 6]);
    expect(_searchEnabled(tester), isFalse);
    expect(find.text(_emptyHint), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(agenda.queries, hasLength(1));
    await _unmount(tester);
  });

  testWidgets('si falla la lista de médicos avisa, permite reintentar y se '
      'puede buscar por especialidad', (tester) async {
    final agenda = _FakeAgenda()
      ..doctorsError = const ApiException(
        'No pudimos cargar los médicos. Probá de nuevo.',
      );
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);

    expect(
      find.text('No pudimos cargar los médicos. Probá de nuevo.'),
      findsOne,
    );
    expect(_doctorField(tester).onChanged, isNull);
    expect(agenda.doctorRequests, [null]);

    await _chooseSpecialty(tester, 'Medicina general');
    expect(_listedNumbers(tester), ['number-11', 'number-12']);

    agenda.doctorsError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(agenda.doctorRequests, [null, null]);
    expect(_doctorField(tester).onChanged, isNotNull);
    expect(_optionValues(tester, _doctorDropdown), [null, 5, 4]);
    await _unmount(tester);
  });

  testWidgets('después de buscar solo por médico se puede agendar', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseDoctor(tester, 'Gómez, Ana');
    await _search(tester);

    await _confirm(tester, 12);

    expect(agenda.booked, [(numberId: 12, referralId: null)]);
    expect(find.text('Consulta agendada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('number-12')), findsNothing);
    await _unmount(tester);
  });

  testWidgets('reservar el último número del médico filtrado deja al '
      'médico elegido y la lista vacía', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _selectSpecialty(tester, 'Medicina general');
    await _chooseDoctor(tester, 'Gómez, Ana');
    await _search(tester);
    expect(_listedNumbers(tester), ['number-12']);

    await _confirm(tester, 12);
    expect(agenda.booked, [(numberId: 12, referralId: null)]);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();

    Finder inDoctor(String text) =>
        find.descendant(of: _doctorDropdown, matching: find.text(text));
    expect(inDoctor('Gómez, Ana'), findsOneWidget);
    expect(inDoctor('Todos'), findsNothing);
    expect(find.text(_noResults), findsOneWidget);
    expect(find.byKey(const Key('number-12')), findsNothing);
    expect(find.byKey(const Key('number-11')), findsNothing);
    expect(_listedNumbers(tester), isEmpty);

    await _search(tester);

    expect(inDoctor('Gómez, Ana'), findsOneWidget);
    expect(inDoctor('Todos'), findsNothing);
    expect(find.text(_noResults), findsOneWidget);
    expect(_listedNumbers(tester), isEmpty);
    expect(agenda.queries.last.doctorId, 5);
    await _unmount(tester);
  });

  testWidgets('escribir Desde y Hasta no consulta; Buscar y Enter sí', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');
    expect(agenda.queries, hasLength(1));

    await _typeDate(tester, 0, '05/11/2026');
    await _typeDate(tester, 1, '10/11/2026');

    expect(agenda.queries, hasLength(1));

    await _search(tester);

    expect(agenda.queries, hasLength(2));
    expect(agenda.queries.last.from, DateTime.utc(2026, 11, 5));
    expect(agenda.queries.last.to, DateTime.utc(2026, 11, 10));

    await _typeDate(tester, 1, '12/11/2026');

    expect(agenda.queries, hasLength(2));

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(agenda.queries, hasLength(3));
    expect(agenda.queries.last.from, DateTime.utc(2026, 11, 5));
    expect(agenda.queries.last.to, DateTime.utc(2026, 11, 12));
    await _unmount(tester);
  });

  testWidgets('Enter en las fechas no busca sin especialidad', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _typeDate(tester, 0, '05/11/2026');

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(agenda.queries, isEmpty);
    expect(find.text(_emptyHint), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('un rango de fechas invertido muestra el error y no consulta', (
    tester,
  ) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');
    await _typeDate(tester, 0, '20/11/2026');
    await _typeDate(tester, 1, '10/11/2026');
    expect(find.text(_invertedRange), findsNothing);

    await _search(tester);

    expect(find.text(_invertedRange), findsOneWidget);
    expect(agenda.queries, hasLength(1));
    await _unmount(tester);
  });

  testWidgets('Orden y Sentido se aplican al instante sobre la búsqueda '
      'hecha', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());
    await _chooseSpecialty(tester, 'Medicina general');
    expect(agenda.queries, hasLength(1));
    expect(_listedNumbers(tester), ['number-11', 'number-12']);

    await tester.tap(find.byKey(const Key('filter-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apellido del médico').last);
    await tester.pumpAndSettle();

    expect(agenda.queries, hasLength(2));
    expect(agenda.queries.last.order, AvailabilityOrder.doctorLastName);
    expect(agenda.queries.last.direction, SortDirection.asc);

    await tester.tap(find.byKey(const Key('filter-direction')));
    await tester.pumpAndSettle();

    expect(agenda.queries, hasLength(3));
    expect(agenda.queries.last.order, AvailabilityOrder.doctorLastName);
    expect(agenda.queries.last.direction, SortDirection.desc);
    expect(_listedNumbers(tester), ['number-12', 'number-11']);
    await _unmount(tester);
  });

  testWidgets('Orden y Sentido antes de buscar no consultan', (tester) async {
    final agenda = await _pump(tester, const AvailabilityScreen());

    await tester.tap(find.byKey(const Key('filter-direction')));
    await tester.pumpAndSettle();

    expect(agenda.queries, isEmpty);
    expect(find.text(_emptyHint), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('al buscar lista los números de la especialidad con sus datos', (
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

  testWidgets('una especialidad con pase agenda con el pase que se muestra', (
    tester,
  ) async {
    final agenda = _FakeAgenda()
      ..referrals.add(_referral(5, _cardio, DateTime.utc(2026, 12, 12)));
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(
      find.text(
        'Esta especialidad requiere pase. Se usará el pase a Cardiología, '
        'vigente hasta 12/12/2026. Se consume al confirmar.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('referral-id')), findsNothing);
    expect(_confirmEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();
    expect(agenda.booked, [(numberId: 21, referralId: 5)]);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('mientras carga los pases muestra un indicador y no deja '
      'confirmar', (tester) async {
    final agenda = _FakeAgenda()..referralsGate = Completer<List<Referral>>();
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _chooseSpecialty(tester, 'Cardiología');
    await tester.tap(find.byKey(const Key('book-21')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isFalse);
    expect(agenda.booked, isEmpty);

    agenda.referralsGate!.complete(const []);
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('si falla la carga de los pases muestra el mensaje de la API y '
      'permite reintentar', (tester) async {
    final agenda = _FakeAgenda()
      ..referralsError = const ApiException(
        'No pudimos conectarnos. Revisá tu conexión y probá de nuevo.',
      );
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(
      find.text('No pudimos conectarnos. Revisá tu conexión y probá de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(_confirmEnabled(tester), isFalse);
    expect(agenda.listReferralsCalls, 1);

    agenda
      ..referralsError = null
      ..referrals.add(_referral(5, _cardio, DateTime.utc(2026, 12, 12)));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(agenda.listReferralsCalls, 2);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.textContaining('Se usará el pase a Cardiología'), findsOne);
    expect(_confirmEnabled(tester), isTrue);
    await _unmount(tester);
  });

  testWidgets('una falla que no es de la API muestra el mensaje genérico', (
    tester,
  ) async {
    final agenda = _FakeAgenda()..referralsError = StateError('interno');
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(find.text('No pudimos cargar tus pases.'), findsOneWidget);
    expect(find.textContaining('interno'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(_confirmEnabled(tester), isFalse);
    await _unmount(tester);
  });

  testWidgets('sin pase utilizable avisa y no deja confirmar', (tester) async {
    final agenda = _FakeAgenda();
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(
      find.text(
        'No encontramos un pase a Cardiología vigente para el '
        '05/11/2026. El médico que te atienda puede emitirte uno.',
      ),
      findsOneWidget,
    );
    expect(_confirmEnabled(tester), isFalse);

    await tester.tap(
      find.byKey(const Key('confirm-booking')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(agenda.booked, isEmpty);
    expect(find.text('Confirmar consulta'), findsOneWidget);
    await _unmount(tester);
  });

  // La lista dice que hay un pase y el servidor lo rechaza (por ejemplo, lo
  // usó otra pestaña entre que se abrió el diálogo y se confirmó).
  testWidgets('si el servidor rechaza el pase, el mensaje se ve', (
    tester,
  ) async {
    final agenda = _FakeAgenda()
      ..referrals.add(_referral(5, _cardio, DateTime.utc(2026, 12, 12)))
      ..bookError = const BookingException(
        BookingFailure.invalidReferral,
        'No existe un pase propio, vigente y sin utilizar para esta '
        'especialidad',
      );
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No existe un pase propio, vigente y sin utilizar para esta '
        'especialidad',
      ),
      findsOneWidget,
    );
    expect(agenda.booked, [(numberId: 21, referralId: 5)]);
    await _unmount(tester);
  });

  testWidgets('tras el rechazo del pase, al reabrir se vuelve a pedir la '
      'lista', (tester) async {
    final agenda = _FakeAgenda()
      ..referrals.add(_referral(5, _cardio, DateTime.utc(2026, 12, 12)))
      ..bookError = const BookingException(
        BookingFailure.invalidReferral,
        'No existe un pase propio, vigente y sin utilizar para esta '
        'especialidad',
      );
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);
    expect(agenda.listReferralsCalls, 1);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();
    expect(agenda.booked, [(numberId: 21, referralId: 5)]);

    // Otra pestaña usó el pase: el servidor ya no lo lista.
    agenda.referrals.clear();
    final book = find.byKey(const Key('book-21'));
    await tester.ensureVisible(book);
    await tester.pumpAndSettle();
    await tester.tap(book);
    await tester.pumpAndSettle();

    expect(agenda.listReferralsCalls, 2);
    expect(
      find.textContaining('No encontramos un pase a Cardiología'),
      findsOne,
    );
    expect(_confirmEnabled(tester), isFalse);
    await _unmount(tester);
  });

  testWidgets('con dos pases válidos envía el primero', (tester) async {
    final agenda = _FakeAgenda()
      ..referrals.addAll([
        _referral(7, _cardio, DateTime.utc(2026, 12, 1)),
        _referral(8, _cardio, DateTime.utc(2026, 12, 20)),
      ]);
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(find.textContaining('vigente hasta 01/12/2026'), findsOneWidget);
    expect(find.textContaining('20/12/2026'), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();

    expect(agenda.booked, [(numberId: 21, referralId: 7)]);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('ignora los pases de otra especialidad', (tester) async {
    final agenda = _FakeAgenda()
      ..referrals.addAll([
        _referral(3, _derm, DateTime.utc(2026, 11, 30)),
        _referral(9, _cardio, DateTime.utc(2026, 12, 15)),
      ]);
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(find.textContaining('Se usará el pase a Cardiología'), findsOne);
    expect(find.textContaining('Dermatología'), findsNothing);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();

    expect(agenda.booked, [(numberId: 21, referralId: 9)]);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('si el único pase es de otra especialidad no deja confirmar', (
    tester,
  ) async {
    final agenda = _FakeAgenda()
      ..referrals.add(_referral(3, _derm, DateTime.utc(2026, 12, 31)));
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(
      find.textContaining('No encontramos un pase a Cardiología'),
      findsOne,
    );
    expect(_confirmEnabled(tester), isFalse);
    expect(agenda.booked, isEmpty);
    await _unmount(tester);
  });

  // El número 21 es del 05/11/2026: un pase que vence el 04/11 ya no sirve y
  // uno que vence el 05/11 sí.
  testWidgets('un pase que vence el día anterior a la consulta no deja '
      'confirmar', (tester) async {
    final agenda = _FakeAgenda()
      ..referrals.add(_referral(4, _cardio, DateTime.utc(2026, 11, 4)));
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(
      find.textContaining('No encontramos un pase a Cardiología'),
      findsOne,
    );
    expect(_confirmEnabled(tester), isFalse);
    expect(agenda.booked, isEmpty);
    await _unmount(tester);
  });

  testWidgets('un pase que vence el mismo día de la consulta se usa', (
    tester,
  ) async {
    final agenda = _FakeAgenda()
      ..referrals.addAll([
        _referral(4, _cardio, DateTime.utc(2026, 11, 4)),
        _referral(6, _cardio, DateTime.utc(2026, 11, 5)),
      ]);
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);

    expect(find.textContaining('vigente hasta 05/11/2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();

    expect(agenda.booked, [(numberId: 21, referralId: 6)]);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('una especialidad sin pase no pide la lista de pases', (
    tester,
  ) async {
    final agenda = _FakeAgenda()
      ..referrals.add(_referral(5, _cardio, DateTime.utc(2026, 12, 12)));
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _chooseSpecialty(tester, 'Medicina general');
    await tester.tap(find.byKey(const Key('book-11')));
    await tester.pumpAndSettle();

    expect(agenda.listReferralsCalls, 0);
    expect(find.textContaining('pase'), findsNothing);
    expect(_confirmEnabled(tester), isTrue);
    await tester.tap(find.byKey(const Key('confirm-booking')));
    await tester.pumpAndSettle();

    expect(agenda.booked, [(numberId: 11, referralId: null)]);
    await tester.tap(find.byKey(const Key('booked-ok')));
    await tester.pumpAndSettle();
    await _unmount(tester);
  });

  testWidgets('la confirmación de una consulta con pase no muestra el pase', (
    tester,
  ) async {
    final agenda = _FakeAgenda()
      ..referrals.add(_referral(5, _cardio, DateTime.utc(2026, 12, 12)));
    await _pump(tester, const AvailabilityScreen(), agenda: agenda);
    await _openCardioBooking(tester);
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

    // Sin overflow y con "Confirmar" tocable: agenda con el pase 5.
    for (final (label, size) in [
      ('360x640', const Size(360, 640)),
      ('360x360', const Size(360, 360)),
      ('320x568', const Size(320, 568)),
    ]) {
      testWidgets('"Confirmar consulta" con pase, a $label', (tester) async {
        final agenda = _FakeAgenda()
          ..referrals.add(_referral(5, _cardio, DateTime.utc(2026, 12, 12)));
        await _pump(tester, const AvailabilityScreen(), agenda: agenda);
        tester.view.physicalSize = size;
        await _openCardioBooking(tester);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Se usará el pase a Cardiología'), findsOne);
        final confirm = find.byKey(const Key('confirm-booking'));
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();

        expect(agenda.booked, [(numberId: 21, referralId: 5)]);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('booked-ok')));
        await tester.pumpAndSettle();
        await _unmount(tester);
      });
    }

    testWidgets('"Confirmar consulta" con error al cargar los pases, a '
        '320x568', (tester) async {
      final agenda = _FakeAgenda()
        ..referralsError = const ApiException(
          'No pudimos conectarnos. Revisá tu conexión y probá de nuevo.',
        );
      await _pump(tester, const AvailabilityScreen(), agenda: agenda);
      tester.view.physicalSize = const Size(320, 568);
      await _openCardioBooking(tester);

      expect(tester.takeException(), isNull);
      final retry = find.text('Reintentar');
      await tester.ensureVisible(retry);
      expect(retry, findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('los dos desplegables, con la ayuda y con médico elegido, no '
        'desbordan a 320x568', (tester) async {
      await _pump(tester, const AvailabilityScreen());
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();

      expect(find.text(_emptyHint), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _chooseDoctor(tester, 'Pérez, Ana');
      await _selectSpecialty(tester, 'Cardiología');

      expect(find.text('Pérez, Ana'), findsOneWidget);
      expect(_doctorField(tester).onChanged, isNotNull);
      expect(_specialtyField(tester).onChanged, isNotNull);
      expect(tester.takeException(), isNull);

      await _search(tester);
      expect(_listedNumbers(tester), ['number-21']);
      expect(tester.takeException(), isNull);
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
