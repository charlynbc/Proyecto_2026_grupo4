import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/core/utils/ui_date.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/especialidades/providers/specialty_repository_provider.dart';
import 'package:agenda_medica/features/especialidades/repositories/fake_specialty_repository.dart';
import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/providers/reinstatement_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_reinstatement_repository.dart';
import 'package:agenda_medica/features/turnos/screens/reinstate_shifts_screen.dart';
import 'package:agenda_medica/features/turnos/screens/shift_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/pump_admin.dart';

const String _warning =
    'Las consultas que se cancelaron por la suspensión no se vuelven a '
    'agendar. Los socios tienen que pedir una nueva consulta.';

const String _notReinstatable =
    'Ese turno no se puede volver a habilitar: no está suspendido o la '
    'fecha ya pasó. Elegí otros turnos de la lista.';

const String _missingFields =
    'Elegí el médico, la especialidad y las dos fechas, y volvé a buscar.';

const String _emptySearch =
    'No hay turnos suspendidos en ese rango. Probá con otras fechas.';

const String _searchFailure =
    'No pudimos conectarnos con el servidor. Revisá tu conexión a internet e '
    'intentá de nuevo.';

/// Hoy en Uruguay. Los turnos del test salen de acá: el 20/10/2026 ya pasó.
DateTime get _today => UruguayTime.today();

DateTime get _yesterday => _today.subtract(const Duration(days: 1));

DateTime get _nextWeek => _today.add(const Duration(days: 7));

DateTime get _inTwoWeeks => _today.add(const Duration(days: 14));

class _PagedListRepository implements ShiftRepository {
  _PagedListRepository(this._inner);

  final ShiftRepository _inner;

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async {
    final all = await _inner.listShifts(
      ShiftFilters(
        doctorId: filters.doctorId,
        specialtyId: filters.specialtyId,
        fromDate: filters.fromDate,
        toDate: filters.toDate,
        state: filters.state,
        page: 0,
        size: 100,
      ),
    );
    final page = filters.page;
    return ShiftPage(
      items: page < all.items.length ? [all.items[page]] : const [],
      page: page,
      size: 1,
      total: all.items.length,
    );
  }

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) =>
      _inner.listDoctors(specialtyId: specialtyId);

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) =>
      _inner.createWeeklyShift(data);

  @override
  Future<WeeklyShift> getWeeklyShift(int id) => _inner.getWeeklyShift(id);
}

class _GateListRepository implements ShiftRepository {
  _GateListRepository(this._inner);

  final ShiftRepository _inner;
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async {
    await _gate.future;
    return _inner.listShifts(filters);
  }

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) =>
      _inner.listDoctors(specialtyId: specialtyId);

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) =>
      _inner.createWeeklyShift(data);

  @override
  Future<WeeklyShift> getWeeklyShift(int id) => _inner.getWeeklyShift(id);
}

class _BrokenListRepository implements ShiftRepository {
  _BrokenListRepository(this._inner);

  final ShiftRepository _inner;

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async {
    throw const ApiException(_searchFailure);
  }

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) =>
      _inner.listDoctors(specialtyId: specialtyId);

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) =>
      _inner.createWeeklyShift(data);

  @override
  Future<WeeklyShift> getWeeklyShift(int id) => _inner.getWeeklyShift(id);
}

class _RecordingListRepository implements ShiftRepository {
  _RecordingListRepository(this._inner);

  final ShiftRepository _inner;
  final List<ShiftFilters> calls = [];

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async {
    calls.add(filters);
    return _inner.listShifts(filters);
  }

  @override
  Future<List<Doctor>> listDoctors({int? specialtyId}) =>
      _inner.listDoctors(specialtyId: specialtyId);

  @override
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data) =>
      _inner.createWeeklyShift(data);

  @override
  Future<WeeklyShift> getWeeklyShift(int id) => _inner.getWeeklyShift(id);
}

class _GateReinstatementRepository implements ShiftReinstatementRepository {
  _GateReinstatementRepository(this.db);

  final FakeShiftDatabase db;
  final Completer<void> _gate = Completer<void>();

  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<ShiftReinstatementResult> reinstate(
    ShiftReinstatement request,
  ) async {
    await _gate.future;
    for (final id in request.shiftIds) {
      db.reinstateShift(id);
    }
    return ShiftReinstatementResult(
      shifts: [
        for (final id in request.shiftIds)
          ReinstatedShift(
            id: id,
            date: db.shifts.firstWhere((shift) => shift.id == id).date,
          ),
      ],
      cancelledAppointments: 0,
    );
  }
}

class _FailingReinstatementRepository
    implements ShiftReinstatementRepository {
  @override
  Future<ShiftReinstatementResult> reinstate(
    ShiftReinstatement request,
  ) async {
    throw const ShiftNotReinstatableException();
  }
}

class _RecordingReinstatementRepository
    implements ShiftReinstatementRepository {
  _RecordingReinstatementRepository(this.db);

  final FakeShiftDatabase db;
  final List<ShiftReinstatement> calls = [];

  @override
  Future<ShiftReinstatementResult> reinstate(ShiftReinstatement request) async {
    calls.add(request);
    for (final id in request.shiftIds) {
      db.reinstateShift(id);
    }
    return ShiftReinstatementResult(
      shifts: [
        for (final id in request.shiftIds)
          ReinstatedShift(
            id: id,
            date: db.shifts.firstWhere((shift) => shift.id == id).date,
          ),
      ],
      cancelledAppointments: 0,
    );
  }
}

int _doctorId(FakeAdminDatabase admin) => admin.accounts
    .firstWhere(
      (account) =>
          account.role == UserRole.medico && account.lastName == 'Méndez',
    )
    .id;

void _oneShift(
  FakeShiftDatabase db,
  FakeAdminDatabase admin,
  DateTime day, {
  required int clinicIndex,
  required String start,
  required String end,
}) {
  db.createWeeklyShift(
    NewWeeklyShift(
      doctorId: _doctorId(admin),
      specialtyId: 1,
      clinicId: admin.clinics[clinicIndex].id,
      weekday: day.weekday,
      startDate: day,
      endDate: day,
      numbers: [
        ShiftNumber(
          number: 1,
          startMinutes: ShiftNumber.parseTime(start),
          endMinutes: ShiftNumber.parseTime(end),
        ),
      ],
    ),
  );
}

/// Hoy y dentro de una semana quedan suspendidos. Dentro de dos semanas
/// queda activo: es el turno que la lista no tiene que mostrar.
void _suspendCurrentAndNext(FakeShiftDatabase db, FakeAdminDatabase admin) {
  final today = UruguayTime.today();
  db.createWeeklyShift(
    NewWeeklyShift(
      doctorId: _doctorId(admin),
      specialtyId: 1,
      clinicId: admin.clinics[0].id,
      weekday: today.weekday,
      startDate: today,
      endDate: today.add(const Duration(days: 14)),
      numbers: [
        ShiftNumber(
          number: 1,
          startMinutes: ShiftNumber.parseTime('09:00'),
          endMinutes: ShiftNumber.parseTime('09:20'),
        ),
      ],
    ),
  );
  final active = today.add(const Duration(days: 14));
  for (final shift in db.shifts) {
    if (shift.date != active) db.suspendShift(shift.id);
  }
}

void _twoSuspendedSameDay(FakeShiftDatabase db, FakeAdminDatabase admin) {
  final day = UruguayTime.today();
  _oneShift(db, admin, day, clinicIndex: 0, start: '09:00', end: '09:20');
  _oneShift(db, admin, day, clinicIndex: 1, start: '15:00', end: '15:20');
  for (final shift in db.shifts) {
    db.suspendShift(shift.id);
  }
}

void _suspendedYesterdayAndToday(
  FakeShiftDatabase db,
  FakeAdminDatabase admin,
) {
  final today = UruguayTime.today();
  _oneShift(
    db,
    admin,
    today.subtract(const Duration(days: 1)),
    clinicIndex: 0,
    start: '09:00',
    end: '09:20',
  );
  _oneShift(db, admin, today, clinicIndex: 0, start: '09:00', end: '09:20');
  for (final shift in db.shifts) {
    db.suspendShift(shift.id);
  }
}

Future<_RecordingReinstatementRepository> _pump(
  WidgetTester tester, {
  ShiftReinstatementRepository? reinstatement,
  ShiftReinstatementRepository Function(FakeShiftDatabase db)? reinstatementOf,
  ShiftRepository Function(FakeShiftDatabase db)? shifts,
  void Function(FakeShiftDatabase db, FakeAdminDatabase admin)? arrange,
}) async {
  final admin = FakeAdminDatabase();
  final db = FakeShiftDatabase(admin, seed: false);
  if (arrange == null) {
    _suspendCurrentAndNext(db, admin);
  } else {
    arrange(db, admin);
  }
  final repository = _RecordingReinstatementRepository(db);
  await pumpAdminScreens(
    tester,
    initialLocation: kReinstateShiftsPath,
    routes: [
      GoRoute(
        path: kReinstateShiftsPath,
        builder: (_, _) => const ReinstateShiftsScreen(),
      ),
    ],
    overrides: [
      shiftRepositoryProvider.overrideWith(
        (ref) async =>
            shifts?.call(db) ??
            FakeShiftRepository(db, latency: Duration.zero),
      ),
      specialtyRepositoryProvider.overrideWith(
        (ref) async => FakeSpecialtyRepository(admin, latency: Duration.zero),
      ),
      reinstatementRepositoryProvider.overrideWith(
        (ref) async =>
            reinstatement ?? reinstatementOf?.call(db) ?? repository,
      ),
    ],
  );
  return repository;
}

Future<void> _choose(WidgetTester tester, Key key, String option) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester) async {
  await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
  await _choose(tester, const Key('reinstate-specialty'), 'Medicina General');
  await tester.enterText(
    find.widgetWithText(TextField, 'Desde'),
    formatUiDate(_today),
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Hasta'),
    formatUiDate(_inTwoWeeks),
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
  await tester.pumpAndSettle();
}

Finder get _rehabilitate =>
    find.widgetWithText(FilledButton, 'Rehabilitar turnos');

/// Fecha mostrada como texto. No cuenta lo escrito en Desde y Hasta:
/// find.text también encuentra el contenido de esos campos.
Finder _shown(String date) => find.byWidgetPredicate(
  (widget) => widget is Text && widget.data == date,
);

void main() {
  testWidgets('la lista muestra solo los turnos suspendidos del rango', (
    tester,
  ) async {
    await _pump(tester);
    await _search(tester);

    expect(_shown(formatUiDate(_today)), findsOneWidget);
    expect(_shown(formatUiDate(_nextWeek)), findsOneWidget);
    expect(_shown(formatUiDate(_inTwoWeeks)), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('sin turnos elegidos el botón está deshabilitado', (
    tester,
  ) async {
    await _pump(tester);
    await _search(tester);

    final button = tester.widget<FilledButton>(_rehabilitate);
    expect(button.onPressed, isNull);
  });

  testWidgets('el diálogo avisa y volver atrás no rehabilita', (tester) async {
    final repository = await _pump(tester);
    await _search(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(_rehabilitate);
    await tester.pumpAndSettle();

    expect(find.text(_warning), findsOneWidget);
    await tester.tap(find.text('No rehabilitar'));
    await tester.pumpAndSettle();

    expect(repository.calls, isEmpty);
    expect(find.text(_warning), findsNothing);
  });

  testWidgets('después de rehabilitar la lista se recarga', (tester) async {
    final repository = await _pump(tester);
    await _search(tester);
    final todayId = repository.db.shifts
        .firstWhere((shift) => shift.date == _today)
        .id;
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(_rehabilitate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver a habilitar'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(1));
    expect(repository.calls.single.shiftIds, [todayId]);
    expect(repository.calls.single.doctorId, isPositive);
    expect(repository.calls.single.specialtyId, 1);
    expect(repository.calls.single.fromDate, _today);
    expect(repository.calls.single.toDate, _inTwoWeeks);
    expect(_shown(formatUiDate(_today)), findsNothing);
    expect(_shown(formatUiDate(_nextWeek)), findsOneWidget);
    expect(_shown(formatUiDate(_inTwoWeeks)), findsNothing);
  });

  testWidgets('dos toques seguidos hacen una sola llamada', (tester) async {
    final repository = await _pump(tester);
    await _search(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(_rehabilitate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver a habilitar'));
    await tester.tap(find.text('Volver a habilitar'));
    await tester.pumpAndSettle();

    expect(repository.calls, hasLength(1));
  });

  testWidgets(
    'si la rehabilitación falla se ve el mensaje y se cierra el diálogo',
    (tester) async {
      await _pump(tester, reinstatement: _FailingReinstatementRepository());
      await _search(tester);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(_rehabilitate);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Volver a habilitar'));
      await tester.pumpAndSettle();

      expect(find.text(_notReinstatable), findsOneWidget);
      expect(find.text(_warning), findsNothing);
    },
  );

  testWidgets('sin médico, especialidad o fechas, buscar avisa', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    expect(find.text(_missingFields), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('un rango sin suspendidos avisa que no hay turnos', (
    tester,
  ) async {
    await _pump(tester);
    await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
    await _choose(
      tester,
      const Key('reinstate-specialty'),
      'Medicina General',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desde'),
      formatUiDate(_inTwoWeeks),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Hasta'),
      formatUiDate(_inTwoWeeks),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    expect(find.text(_emptySearch), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('mientras busca se ve el indicador y después las fechas', (
    tester,
  ) async {
    final gate = Completer<_GateListRepository>();
    await _pump(
      tester,
      shifts: (db) {
        final repository = _GateListRepository(
          FakeShiftRepository(db, latency: Duration.zero),
        );
        gate.complete(repository);
        return repository;
      },
    );
    await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
    await _choose(
      tester,
      const Key('reinstate-specialty'),
      'Medicina General',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desde'),
      formatUiDate(_today),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Hasta'),
      formatUiDate(_inTwoWeeks),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.future.then((repository) => repository.release());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(_shown(formatUiDate(_today)), findsOneWidget);
  });

  testWidgets('si la búsqueda falla se ve el mensaje de la red', (
    tester,
  ) async {
    await _pump(
      tester,
      shifts: (db) => _BrokenListRepository(
        FakeShiftRepository(db, latency: Duration.zero),
      ),
    );
    await _search(tester);

    expect(find.text(_searchFailure), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('la búsqueda trae los suspendidos de todas las páginas', (
    tester,
  ) async {
    await _pump(
      tester,
      shifts: (db) => _PagedListRepository(
        FakeShiftRepository(db, latency: Duration.zero),
      ),
    );
    await _search(tester);

    expect(_shown(formatUiDate(_today)), findsOneWidget);
    expect(_shown(formatUiDate(_nextWeek)), findsOneWidget);
  });

  testWidgets('la fila muestra el horario y el consultorio', (tester) async {
    await _pump(tester, arrange: _twoSuspendedSameDay);
    await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
    await _choose(
      tester,
      const Key('reinstate-specialty'),
      'Medicina General',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desde'),
      formatUiDate(_today),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Hasta'),
      formatUiDate(_today),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    expect(_shown(formatUiDate(_today)), findsNWidgets(2));
    expect(_shown('09:00 – 09:20'), findsOneWidget);
    expect(_shown('15:00 – 15:20'), findsOneWidget);
    expect(_shown('Consultorio 3'), findsOneWidget);
    expect(_shown('Consultorio 7'), findsOneWidget);
  });

  testWidgets('una fecha pasada no se ofrece', (tester) async {
    final recorded = Completer<_RecordingListRepository>();
    await _pump(
      tester,
      arrange: _suspendedYesterdayAndToday,
      shifts: (db) {
        final repository = _RecordingListRepository(
          FakeShiftRepository(db, latency: Duration.zero),
        );
        recorded.complete(repository);
        return repository;
      },
    );
    await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
    await _choose(
      tester,
      const Key('reinstate-specialty'),
      'Medicina General',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desde'),
      formatUiDate(_yesterday),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Hasta'),
      formatUiDate(_today),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    expect(_shown(formatUiDate(_yesterday)), findsNothing);
    expect(_shown(formatUiDate(_today)), findsOneWidget);
    final repository = await recorded.future;
    expect(repository.calls.single.fromDate, _today);
  });

  testWidgets('al rehabilitar un turno se avisa que fue uno', (tester) async {
    await _pump(tester);
    await _search(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(_rehabilitate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver a habilitar'));
    await tester.pumpAndSettle();

    expect(find.text('Se volvió a habilitar 1 turno.'), findsOneWidget);
  });

  testWidgets('al rehabilitar varios se avisa cuántos fueron', (tester) async {
    await _pump(tester);
    await _search(tester);
    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    await tester.tap(_rehabilitate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver a habilitar'));
    await tester.pumpAndSettle();

    expect(find.text('Se volvieron a habilitar 2 turnos.'), findsOneWidget);
  });

  testWidgets('seleccionar todas marca los turnos del rango', (tester) async {
    await _pump(tester);

    expect(find.text('Seleccionar todas'), findsNothing);

    await _search(tester);

    expect(find.text('Seleccionar todas'), findsOneWidget);
    await tester.tap(find.text('Seleccionar todas'));
    await tester.pumpAndSettle();

    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(boxes, hasLength(2));
    expect(boxes.every((box) => box.value == true), isTrue);
    expect(tester.widget<FilledButton>(_rehabilitate).onPressed, isNotNull);

    await tester.tap(find.text('Seleccionar todas'));
    await tester.pumpAndSettle();

    final cleared = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(cleared.every((box) => box.value == false), isTrue);
    expect(tester.widget<FilledButton>(_rehabilitate).onPressed, isNull);
  });

  testWidgets('mientras se rehabilita el diálogo no se puede cerrar', (
    tester,
  ) async {
    _GateReinstatementRepository? gate;
    await _pump(
      tester,
      reinstatementOf: (db) {
        gate = _GateReinstatementRepository(db);
        return gate!;
      },
    );
    addTearDown(() => gate?.release());
    await _search(tester);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(_rehabilitate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Volver a habilitar'));
    await tester.pump();

    TextButton button(String label) => tester.widget<TextButton>(
      find.widgetWithText(TextButton, label),
    );
    expect(button('No rehabilitar').onPressed, isNull);
    expect(button('Volver a habilitar').onPressed, isNull);

    gate!.release();
    await tester.pumpAndSettle();

    expect(find.text(_warning), findsNothing);
    expect(_shown(formatUiDate(_today)), findsNothing);
  });

  testWidgets('un rango entero en el pasado no consulta al servidor', (
    tester,
  ) async {
    final recorded = Completer<_RecordingListRepository>();
    await _pump(
      tester,
      shifts: (db) {
        final repository = _RecordingListRepository(
          FakeShiftRepository(db, latency: Duration.zero),
        );
        recorded.complete(repository);
        return repository;
      },
    );
    final repository = await recorded.future;
    await _choose(tester, const Key('reinstate-doctor'), 'Carla Méndez');
    await _choose(
      tester,
      const Key('reinstate-specialty'),
      'Medicina General',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Desde'),
      formatUiDate(_yesterday),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Hasta'),
      formatUiDate(_yesterday),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
    await tester.pumpAndSettle();

    expect(find.text(_emptySearch), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(repository.calls, isEmpty);
  });

  testWidgets(
    'durante el pedido no se cierra el diálogo y si se cierra igual se avisa',
    (tester) async {
      _GateReinstatementRepository? gate;
      await _pump(
        tester,
        reinstatementOf: (db) {
          gate = _GateReinstatementRepository(db);
          return gate!;
        },
      );
      addTearDown(() => gate?.release());
      await _search(tester);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(_rehabilitate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver a habilitar'));
      await tester.pump();

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.text(_warning), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(_warning), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(_warning), findsOneWidget);

      Navigator.of(
        tester.element(find.text(_warning)),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();

      gate!.release();
      await tester.pumpAndSettle();

      expect(find.text('Se volvió a habilitar 1 turno.'), findsOneWidget);
      expect(_shown(formatUiDate(_today)), findsNothing);
    },
  );
}
