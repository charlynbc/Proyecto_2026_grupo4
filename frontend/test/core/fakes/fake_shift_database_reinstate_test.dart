import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_reinstatement_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

void main() {
  late FakeAdminDatabase admin;
  late FakeShiftDatabase db;

  setUp(() {
    admin = FakeAdminDatabase();
    db = FakeShiftDatabase(admin, seed: false);
  });

  int createOneShift() {
    final doctor = admin.accounts.firstWhere(
      (a) => a.role == UserRole.medico && a.lastName == 'Méndez',
    );
    db.createWeeklyShift(
      NewWeeklyShift(
        doctorId: doctor.id,
        specialtyId: 1,
        clinicId: admin.clinics[0].id,
        weekday: 2,
        startDate: DateTime.utc(2026, 10, 20),
        endDate: DateTime.utc(2026, 10, 20),
        numbers: [_n(1, '09:00', '09:20')],
      ),
    );
    return db.shifts.single.id;
  }

  test('reinstateShift deja activo un turno suspendido', () {
    final id = createOneShift();
    db.suspendShift(id);

    db.reinstateShift(id);

    expect(db.shifts.single.state, ShiftState.active);
  });

  test('reinstateShift sobre un turno activo lanza no rehabilitable', () {
    final id = createOneShift();

    expect(
      () => db.reinstateShift(id),
      throwsA(
        isA<ShiftNotReinstatableException>().having(
          (e) => e.code,
          'code',
          'TURNO_NO_REHABILITABLE',
        ),
      ),
    );
    expect(db.shifts.single.state, ShiftState.active);
  });
}
