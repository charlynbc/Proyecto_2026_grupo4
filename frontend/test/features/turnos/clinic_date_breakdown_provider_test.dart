import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/providers/clinic_date_breakdown_provider.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_clock_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _doctor = DoctorRef(id: 17, firstName: 'Marta', lastName: 'Rodríguez');
const _specialty = Specialty(
  id: 3,
  name: 'Cardiología',
  requiresReferral: true,
);
const _room5 = Clinic(id: 5, name: 'Consultorio 5', location: 'Piso 2');
const _room7 = Clinic(id: 7, name: 'Consultorio 7', location: 'Piso 1');

/// Hoy es martes 20/10/2026.
final _today = DateTime.utc(2026, 10, 20);

final _pattern = WeeklyShift(
  id: 120,
  doctor: _doctor,
  specialty: _specialty,
  clinic: _room5,
  weekday: 2,
  startDate: DateTime.utc(2026, 10, 6),
  endDate: DateTime.utc(2026, 12, 29),
  numbers: const [],
  shiftCount: 13,
  clinicVariesByDate: true,
);

Shift _shift(
  int id,
  DateTime date,
  Clinic clinic, {
  ShiftState state = ShiftState.active,
  int weeklyShiftId = 120,
}) => Shift(
  id: id,
  weeklyShiftId: weeklyShiftId,
  date: date,
  weekday: 2,
  startMinutes: 9 * 60,
  endMinutes: 10 * 60,
  doctor: _doctor,
  specialty: _specialty,
  clinic: clinic,
  numberCount: 3,
  state: state,
);

/// Devuelve las filas dadas, paginadas como el servidor, y anota qué se pidió.
class _PagedShifts extends FakeShiftRepository {
  _PagedShifts(super.db, this.rows) : super(latency: Duration.zero);

  final List<Shift> rows;
  final requests = <ShiftFilters>[];

  @override
  Future<WeeklyShift> getWeeklyShift(int id) async => _pattern;

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async {
    requests.add(filters);
    final start = filters.page * filters.size;
    return ShiftPage(
      items: rows.skip(start).take(filters.size).toList(),
      page: filters.page,
      size: filters.size,
      total: rows.length,
    );
  }
}

(ProviderContainer, _PagedShifts) _container(List<Shift> rows) {
  final repository = _PagedShifts(
    FakeShiftDatabase(FakeAdminDatabase(), seed: false),
    rows,
  );
  final container = ProviderContainer(
    overrides: [
      shiftRepositoryProvider.overrideWith((ref) async => repository),
      suspensionClockProvider.overrideWithValue(() => _today),
    ],
  );
  addTearDown(container.dispose);
  return (container, repository);
}

void main() {
  test('cuenta por consultorio las fechas de hoy en adelante y aparta las '
      'pasadas', () async {
    final (container, _) = _container([
      _shift(1, DateTime.utc(2026, 10, 6), _room5),
      _shift(2, DateTime.utc(2026, 10, 13), _room5),
      // Hoy cuenta como "de hoy en adelante".
      _shift(3, DateTime.utc(2026, 10, 20), _room7),
      _shift(4, DateTime.utc(2026, 10, 27), _room5),
      _shift(5, DateTime.utc(2026, 11, 3), _room5, state: ShiftState.suspended),
      _shift(6, DateTime.utc(2026, 11, 10), _room5),
      _shift(7, DateTime.utc(2026, 11, 17), _room7),
      // De otro turno semanal del mismo médico, especialidad y día.
      _shift(8, DateTime.utc(2026, 10, 27), _room7, weeklyShiftId: 130),
    ]);

    final breakdown = await container.read(
      clinicDateBreakdownProvider(120).future,
    );

    expect(breakdown.past, 2);
    expect(breakdown.upcoming, hasLength(2));
    expect(breakdown.upcoming[0].clinic.name, 'Consultorio 5');
    expect(breakdown.upcoming[0].clinic.location, 'Piso 2');
    expect(breakdown.upcoming[0].dates, 3);
    expect(breakdown.upcoming[0].suspended, 1);
    expect(breakdown.upcoming[1].clinic.name, 'Consultorio 7');
    expect(breakdown.upcoming[1].clinic.location, 'Piso 1');
    expect(breakdown.upcoming[1].dates, 2);
    expect(breakdown.upcoming[1].suspended, 0);
  });

  test('pide el listado con el médico, la especialidad, el día y la vigencia '
      'del patrón, de a 100', () async {
    final (container, repository) = _container([
      _shift(1, DateTime.utc(2026, 10, 27), _room5),
    ]);

    await container.read(clinicDateBreakdownProvider(120).future);

    expect(repository.requests, hasLength(1));
    final request = repository.requests.single;
    expect(request.doctorId, 17);
    expect(request.specialtyId, 3);
    expect(request.weekday, 2);
    expect(request.fromDate, DateTime.utc(2026, 10, 6));
    expect(request.toDate, DateTime.utc(2026, 12, 29));
    expect(request.size, 100);
    expect(request.page, 0);
  });

  test('con más de 100 filas pide la segunda página y no pierde ninguna', () async {
    // 150 filas: 130 del turno 120 (una por semana) y 20 de otro turno
    // intercaladas. Las primeras 30 del turno son pasadas (Consultorio 5);
    // de las 100 siguientes, 60 son del Consultorio 5 y 40 del 7. Se suspenden
    // las filas del turno 120 cuyo índice es múltiplo de 10.
    final rows = <Shift>[];
    for (var i = 0; i < 130; i++) {
      final date = DateTime.utc(2026, 10, 20).add(Duration(days: 7 * (i - 30)));
      rows.add(
        _shift(
          1000 + i,
          date,
          i < 90 ? _room5 : _room7,
          state: i >= 30 && i % 10 == 0
              ? ShiftState.suspended
              : ShiftState.active,
        ),
      );
      if (i % 6 == 0 && i < 120) {
        rows.add(_shift(5000 + i, date, _room7, weeklyShiftId: 130));
      }
    }
    expect(rows, hasLength(150));
    final (container, repository) = _container(rows);

    final breakdown = await container.read(
      clinicDateBreakdownProvider(120).future,
    );

    expect(repository.requests.map((r) => r.page), [0, 1]);
    expect(breakdown.past, 30);
    expect(breakdown.upcoming, hasLength(2));
    expect(breakdown.upcoming[0].clinic.name, 'Consultorio 5');
    expect(breakdown.upcoming[0].dates, 60);
    expect(breakdown.upcoming[0].suspended, 6);
    expect(breakdown.upcoming[1].clinic.name, 'Consultorio 7');
    expect(breakdown.upcoming[1].dates, 40);
    expect(breakdown.upcoming[1].suspended, 4);
  });

  test('sin filas del turno no hay consultorios ni fechas pasadas', () async {
    final (container, _) = _container([
      _shift(8, DateTime.utc(2026, 10, 27), _room7, weeklyShiftId: 130),
    ]);

    final breakdown = await container.read(
      clinicDateBreakdownProvider(120).future,
    );

    expect(breakdown.upcoming, isEmpty);
    expect(breakdown.past, 0);
  });

  test('si el listado falla, el provider da el error', () async {
    final repository = _FailingShifts(
      FakeShiftDatabase(FakeAdminDatabase(), seed: false),
    );
    final container = ProviderContainer(
      overrides: [
        shiftRepositoryProvider.overrideWith((ref) async => repository),
        suspensionClockProvider.overrideWithValue(() => _today),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(clinicDateBreakdownProvider(120).future),
      throwsA(isA<Exception>()),
    );
  });
}

class _FailingShifts extends FakeShiftRepository {
  _FailingShifts(super.db) : super(latency: Duration.zero);

  @override
  Future<WeeklyShift> getWeeklyShift(int id) async => _pattern;

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) async =>
      throw Exception('sin conexión');
}
