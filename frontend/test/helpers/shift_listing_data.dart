import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

/// Los turnos con los que se prueba el listado: 32 fechas concretas, sin
/// sembrar el resto (`seed: false`), para que los conteos no dependan de la
/// fecha de hoy.
///
/// | Configuración | Médico | Especialidad | Consultorio | Día | Fechas |
/// |---|---|---|---|---|---|
/// | 1 | Méndez | Medicina General | Consultorio 3 | martes | 20/10, 27/10, 3/11, 10/11 (la del 27/10, suspendida) |
/// | 2 | Silva | Cardiología | Consultorio 7 | jueves | 22/10, 29/10, 5/11, 12/11 (la del 5/11, suspendida) |
/// | 3 | Acosta | Dermatología | Consultorio 12 | lunes | 23 lunes desde el 19/10/2026 hasta el 22/03/2027 |
/// | 4 | Silva | Cardiología | Consultorio 7 | lunes | 19/10 a las 08:00 |
///
/// Ordenadas por fecha y horario, la primera es la 4 (19/10 08:00) y la
/// segunda la 3 (19/10 10:00).
FakeShiftDatabase buildListingDb(FakeAdminDatabase admin) {
  final db = FakeShiftDatabase(admin, seed: false);
  int doctor(String lastName) => admin.accounts
      .firstWhere((a) => a.role == UserRole.medico && a.lastName == lastName)
      .id;

  final first = db.createWeeklyShift(
    NewWeeklyShift(
      doctorId: doctor('Méndez'),
      specialtyId: 1,
      clinicId: admin.clinics[0].id,
      weekday: 2,
      startDate: DateTime.utc(2026, 10, 20),
      endDate: DateTime.utc(2026, 11, 10),
      numbers: [_n(1, '09:00', '09:20'), _n(2, '09:20', '09:40')],
    ),
  );
  final second = db.createWeeklyShift(
    NewWeeklyShift(
      doctorId: doctor('Silva'),
      specialtyId: 2,
      clinicId: admin.clinics[1].id,
      weekday: 4,
      startDate: DateTime.utc(2026, 10, 22),
      endDate: DateTime.utc(2026, 11, 12),
      numbers: [_n(1, '15:00', '15:30'), _n(2, '15:30', '16:00')],
    ),
  );
  db.createWeeklyShift(
    NewWeeklyShift(
      doctorId: doctor('Acosta'),
      specialtyId: 3,
      clinicId: admin.clinics[2].id,
      weekday: 1,
      startDate: DateTime.utc(2026, 10, 19),
      endDate: DateTime.utc(2027, 3, 22),
      numbers: [
        _n(1, '10:00', '10:20'),
        _n(2, '10:20', '10:40'),
        _n(3, '10:40', '11:00'),
      ],
    ),
  );
  db.createWeeklyShift(
    NewWeeklyShift(
      doctorId: doctor('Silva'),
      specialtyId: 2,
      clinicId: admin.clinics[1].id,
      weekday: 1,
      startDate: DateTime.utc(2026, 10, 19),
      endDate: DateTime.utc(2026, 10, 19),
      numbers: [_n(1, '08:00', '08:20')],
    ),
  );

  db.suspendShift(
    db.shifts
        .firstWhere(
          (s) =>
              s.weeklyShiftId == first.id &&
              s.date == DateTime.utc(2026, 10, 27),
        )
        .id,
  );
  db.suspendShift(
    db.shifts
        .firstWhere(
          (s) =>
              s.weeklyShiftId == second.id &&
              s.date == DateTime.utc(2026, 11, 5),
        )
        .id,
  );
  return db;
}
