import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_filters.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_page.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/suspension_filter.dart';
import 'package:agenda_medica/features/turnos/providers/shift_repository_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_candidates_provider.dart';
import 'package:agenda_medica/features/turnos/providers/suspension_clock_provider.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Hoy" de todos los tests: miercoles 04/11/2026. Se inyecta, no se lee el
/// reloj.
final _today = DateTime.utc(2026, 11, 4);

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

/// El repositorio de turnos falso con las llamadas a `listShifts` contadas.
class _CountingShiftRepository implements ShiftRepository {
  _CountingShiftRepository(this._inner);

  final ShiftRepository _inner;
  int listShiftsCalls = 0;

  @override
  Future<ShiftPage> listShifts(ShiftFilters filters) {
    listShiftsCalls++;
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

/// Turnos de los tests, sin sembrar el resto (`seed: false`).
///
/// Configuracion 1: Mendez, Medicina General (especialidad 1), todos los
/// miercoles del 07/10/2026 al 30/12/2026. Ids por fecha: 1 = 07/10, 2 = 14/10,
/// 3 = 21/10, 4 = 28/10, 5 = 04/11 (hoy), 6 = 11/11, 7 = 18/11, 8 = 25/11,
/// 9 = 02/12, 10 = 09/12, 11 = 16/12, 12 = 23/12, 13 = 30/12.
///
/// Configuracion 2: Silva, Cardiologia (especialidad 2), el jueves 05/11/2026:
/// el turno 14.
class _Setup {
  _Setup({this.mendezEnd}) {
    admin = FakeAdminDatabase();
    db = FakeShiftDatabase(admin, seed: false);
    mendezId = _doctor('Méndez');
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: mendezId,
        specialtyId: 1,
        clinicId: admin.clinics[0].id,
        weekday: 3,
        startDate: mendezEnd == null
            ? DateTime.utc(2026, 10, 7)
            : DateTime.utc(2026, 11, 4),
        endDate: mendezEnd ?? DateTime.utc(2026, 12, 30),
        numbers: [_n(1, '09:00', '09:20')],
      ),
    );
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: _doctor('Silva'),
        specialtyId: 2,
        clinicId: admin.clinics[1].id,
        weekday: 4,
        startDate: DateTime.utc(2026, 11, 5),
        endDate: DateTime.utc(2026, 11, 5),
        numbers: [_n(1, '15:00', '15:30')],
      ),
    );
    shifts = _CountingShiftRepository(
      FakeShiftRepository(db, latency: Duration.zero),
    );
    container = ProviderContainer(
      overrides: [
        shiftRepositoryProvider.overrideWith((ref) async => shifts),
        suspensionClockProvider.overrideWithValue(() => _today),
      ],
    );
  }

  /// Cuando no es null, la configuracion 1 arranca el 04/11 y termina aca.
  final DateTime? mendezEnd;
  late final FakeAdminDatabase admin;
  late final FakeShiftDatabase db;
  late final int mendezId;
  late final _CountingShiftRepository shifts;
  late final ProviderContainer container;

  int _doctor(String lastName) => admin.accounts
      .firstWhere((a) => a.role == UserRole.medico && a.lastName == lastName)
      .id;

  SuspensionFilter filter({DateTime? fromDate, DateTime? toDate}) =>
      SuspensionFilter(
        doctorId: mendezId,
        specialtyId: 1,
        fromDate: fromDate ?? DateTime.utc(2026, 10, 1),
        toDate: toDate ?? DateTime.utc(2026, 12, 30),
      );

  Future<List<int>> candidateIds(SuspensionFilter filter) async {
    final shifts = await container.read(
      suspensionCandidatesProvider(filter).future,
    );
    return [for (final shift in shifts) shift.id];
  }
}

void main() {
  late _Setup s;

  setUp(() => s = _Setup());
  tearDown(() => s.container.dispose());

  group('lo que ofrece', () {
    test(
      'no ofrece fechas pasadas: con desde el 01/10 salen del 5 al 13',
      () async {
        expect(await s.candidateIds(s.filter()), [
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
        ]);
      },
    );

    test('no ofrece turnos suspendidos', () async {
      s.db.suspendShift(8);

      expect(await s.candidateIds(s.filter()), [5, 6, 7, 9, 10, 11, 12, 13]);
    });

    test('solo los del medico y la especialidad del filtro', () async {
      // El turno 14 es de Silva: no aparece.
      expect(await s.candidateIds(s.filter()), isNot(contains(14)));
    });

    test('respeta el "hasta": del 04/11 al 18/11 son 5, 6 y 7', () async {
      final ids = await s.candidateIds(
        s.filter(
          fromDate: DateTime.utc(2026, 11, 4),
          toDate: DateTime.utc(2026, 11, 18),
        ),
      );

      expect(ids, [5, 6, 7]);
    });

    test('un rango entero en el pasado da lista vacia, sin error', () async {
      final ids = await s.candidateIds(
        s.filter(
          fromDate: DateTime.utc(2026, 10, 1),
          toDate: DateTime.utc(2026, 11, 3),
        ),
      );

      expect(ids, isEmpty);
      // Con "desde" ajustado a hoy (04/11) queda mayor que "hasta" (03/11):
      // el servidor real lo rechazaria con 400, asi que ni se le pregunta.
      expect(s.shifts.listShiftsCalls, 0);
    });

    test('van ordenados por fecha', () async {
      final shifts = await s.container.read(
        suspensionCandidatesProvider(s.filter()).future,
      );

      expect(shifts.first.date, DateTime.utc(2026, 11, 4));
      expect(shifts.last.date, DateTime.utc(2026, 12, 30));
    });

    test('el mismo filtro da el mismo provider (la clave es por valor)', () {
      expect(
        suspensionCandidatesProvider(s.filter()),
        suspensionCandidatesProvider(s.filter()),
      );
    });
  });

  group('tope de 500', () {
    // Cada miercoles es una fecha. Desde el 04/11/2026, N miercoles terminan
    // 7 * (N - 1) dias despues.
    DateTime endAfter(int wednesdays) =>
        DateTime.utc(2026, 11, 4 + 7 * (wednesdays - 1));

    test('101 fechas se traen completas (son dos paginas de 100)', () async {
      final big = _Setup(mendezEnd: endAfter(101));
      addTearDown(big.container.dispose);

      final ids = await big.candidateIds(
        big.filter(fromDate: DateTime.utc(2026, 11, 4), toDate: endAfter(101)),
      );

      expect(ids, hasLength(101));
      expect(big.shifts.listShiftsCalls, 2);
    });

    test('500 fechas se ofrecen', () async {
      final big = _Setup(mendezEnd: endAfter(500));
      addTearDown(big.container.dispose);

      final ids = await big.candidateIds(
        big.filter(fromDate: DateTime.utc(2026, 11, 4), toDate: endAfter(500)),
      );

      expect(ids, hasLength(500));
    });

    test('501 fechas no se ofrecen: pide achicar el rango', () async {
      final big = _Setup(mendezEnd: endAfter(501));
      addTearDown(big.container.dispose);

      await expectLater(
        big.candidateIds(
          big.filter(
            fromDate: DateTime.utc(2026, 11, 4),
            toDate: endAfter(501),
          ),
        ),
        throwsA(isA<TooManySuspensionCandidatesException>()),
      );
    });
  });
}
