import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_reinstatement_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_reinstatement_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeShiftDatabase db;
  late FakeShiftReinstatementRepository repository;

  setUp(() {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 10, 20, 15),
    );
    db = FakeShiftDatabase(admin, seed: false);
    final doctor = admin.accounts.firstWhere(
      (account) =>
          account.role == UserRole.medico && account.lastName == 'Méndez',
    );
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: doctor.id,
        specialtyId: 1,
        clinicId: admin.clinics[0].id,
        weekday: 2,
        startDate: DateTime.utc(2026, 10, 20),
        endDate: DateTime.utc(2026, 10, 20),
        numbers: [
          ShiftNumber(
            number: 1,
            startMinutes: ShiftNumber.parseTime('09:00'),
            endMinutes: ShiftNumber.parseTime('09:20'),
          ),
        ],
      ),
    );
    repository = FakeShiftReinstatementRepository(db, latency: Duration.zero);
  });

  ShiftReinstatement request(int id) => ShiftReinstatement(
    doctorId: db.shifts.single.doctorId,
    specialtyId: 1,
    fromDate: DateTime.utc(2026, 10, 20),
    toDate: DateTime.utc(2026, 10, 20),
    shiftIds: [id],
  );

  test('un turno suspendido vuelve a activo y no restaura consultas', () async {
    final id = db.shifts.single.id;
    db.suspendShift(id);

    final result = await repository.reinstate(request(id));

    expect(db.shifts.single.state, ShiftState.active);
    expect(result.cancelledAppointments, 0);
    expect(result.shifts.single.id, id);
    expect(result.shifts.single.date, DateTime.utc(2026, 10, 20));
  });

  test('un turno activo no se puede rehabilitar', () async {
    final id = db.shifts.single.id;

    expect(
      () => repository.reinstate(request(id)),
      throwsA(
        isA<ShiftNotReinstatableException>().having(
          (error) => error.code,
          'code',
          'TURNO_NO_REHABILITABLE',
        ),
      ),
    );
    expect(db.shifts.single.state, ShiftState.active);
  });

  test('una fecha pasada no se rehabilita y sigue suspendida', () async {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 10, 21, 15),
    );
    final database = FakeShiftDatabase(admin, seed: false);
    final doctor = admin.accounts.firstWhere(
      (account) =>
          account.role == UserRole.medico && account.lastName == 'Méndez',
    );
    database.createWeeklyShift(
      NewWeeklyShift(
        doctorId: doctor.id,
        specialtyId: 1,
        clinicId: admin.clinics[0].id,
        weekday: 2,
        startDate: DateTime.utc(2026, 10, 20),
        endDate: DateTime.utc(2026, 10, 20),
        numbers: [
          ShiftNumber(
            number: 1,
            startMinutes: ShiftNumber.parseTime('09:00'),
            endMinutes: ShiftNumber.parseTime('09:20'),
          ),
        ],
      ),
    );
    final id = database.shifts.single.id;
    database.suspendShift(id);
    final past = FakeShiftReinstatementRepository(
      database,
      latency: Duration.zero,
    );

    expect(
      () => past.reinstate(
        ShiftReinstatement(
          doctorId: doctor.id,
          specialtyId: 1,
          fromDate: DateTime.utc(2026, 10, 20),
          toDate: DateTime.utc(2026, 10, 20),
          shiftIds: [id],
        ),
      ),
      throwsA(
        isA<ShiftNotReinstatableException>().having(
          (error) => error.code,
          'code',
          'TURNO_NO_REHABILITABLE',
        ),
      ),
    );
    expect(database.shifts.single.state, ShiftState.suspended);
  });

  test('si un turno no existe no rehabilita ninguno', () async {
    final id = db.shifts.single.id;
    db.suspendShift(id);

    expect(
      () => repository.reinstate(
        ShiftReinstatement(
          doctorId: db.shifts.single.doctorId,
          specialtyId: 1,
          fromDate: DateTime.utc(2026, 10, 20),
          toDate: DateTime.utc(2026, 10, 20),
          shiftIds: [id, id + 1],
        ),
      ),
      throwsA(
        isA<ShiftNotFoundException>().having(
          (error) => error.code,
          'code',
          'NO_ENCONTRADO',
        ),
      ),
    );
    expect(db.shifts.single.state, ShiftState.suspended);
  });
}
