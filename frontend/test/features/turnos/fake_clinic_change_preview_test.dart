import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_weekly_shift_clinic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la vista previa fake es de solo lectura e incluye fechas suspendidas',
      () async {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 11, 10, 15),
    );
    final db = FakeShiftDatabase(admin);
    final repository = FakeWeeklyShiftClinicRepository(
      db,
      latency: Duration.zero,
    );
    final oldClinics = [for (final s in db.shifts) s.clinicId];
    final oldPatternClinic = db.weeklyShifts.first.clinic.id;
    final destination = admin.clinics.last.id;

    final result = await repository.previewClinicChange(1, destination);

    expect(result.dates, isNotEmpty);
    expect(result.dates.map((d) => d.date), orderedEquals(
      [...result.dates.map((d) => d.date)]..sort(),
    ));
    expect(
      result.dates.any((d) => d.state == ShiftState.suspended),
      isTrue,
    );
    expect([for (final s in db.shifts) s.clinicId], oldClinics);
    expect(db.weeklyShifts.first.clinic.id, oldPatternClinic);
  });

  test('la vista previa muestra las consultas agendadas del patrón de Silva',
      () async {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 11, 10, 15),
    );
    final db = FakeShiftDatabase(admin);
    final repository = FakeWeeklyShiftClinicRepository(
      db,
      latency: Duration.zero,
    );
    final result = await repository.previewClinicChange(
      2,
      admin.clinics.last.id,
    );

    expect(
      result.dates.any((date) => date.requiresConfirmation),
      isTrue,
    );
  });
}
