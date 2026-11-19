import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/weekly_shift_clinic_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/fake_weekly_shift_clinic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'la vista previa fake es de solo lectura e incluye fechas suspendidas',
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
      expect(
        result.dates.map((d) => d.date),
        orderedEquals([...result.dates.map((d) => d.date)]..sort()),
      );
      expect(result.dates.any((d) => d.state == ShiftState.suspended), isTrue);
      expect([for (final s in db.shifts) s.clinicId], oldClinics);
      expect(db.weeklyShifts.first.clinic.id, oldPatternClinic);
    },
  );

  test(
    'la vista previa muestra las consultas agendadas del patrón de Silva',
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

      expect(result.dates.any((date) => date.requiresConfirmation), isTrue);
    },
  );
  test('un cambio parcial conserva las fechas no elegidas y el patrón', () {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 11, 10, 15),
    );
    final db = FakeShiftDatabase(admin);
    final pattern = db.weeklyShifts.first;
    final targetClinic = admin.clinics.last.id;
    final upcoming = db.shifts
        .where((shift) => shift.weeklyShiftId == pattern.id)
        .toList();
    final selected = upcoming.firstWhere(
      (shift) => shift.state == ShiftState.active,
    );
    final notSelected = upcoming.firstWhere((shift) => shift.id != selected.id);

    final originalClinic = notSelected.clinicId;
    final result = db.changeClinic(
      pattern.id,
      targetClinic,
      turnoIds: [selected.id],
    );

    expect(selected.clinicId, targetClinic);
    expect(notSelected.clinicId, originalClinic);
    expect(result.clinic.id, pattern.clinic.id);
    expect(result.clinicVariesByDate, isTrue);
  });

  test('consultas agendadas requieren confirmación y no se cancelan', () {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 11, 10, 15),
    );
    final db = FakeShiftDatabase(admin);
    final booked = db.shifts.firstWhere((shift) => shift.weeklyShiftId == 2);
    final target = admin.clinics.last.id;
    final original = booked.clinicId;
    expect(
      () => db.changeClinic(2, target, turnoIds: [booked.id]),
      throwsA(isA<ShiftNotModifiableException>()),
    );
    expect(booked.clinicId, original);

    db.changeClinic(
      2,
      target,
      turnoIds: [booked.id],
      confirmarConConsultas: true,
    );
    expect(booked.clinicId, target);
    expect(db.agendadasPorTurno[booked.id], 2);
  });

  group('confirmación atómica con el total de consultas visto', () {
    late FakeAdminDatabase admin;
    late FakeShiftDatabase db;
    late FakeShift booked;
    late int target;

    setUp(() {
      admin = FakeAdminDatabase(clock: () => DateTime.utc(2026, 11, 10, 15));
      db = FakeShiftDatabase(admin);
      // La fecha de la configuración 2 tiene 2 consultas agendadas.
      booked = db.shifts.firstWhere((shift) => shift.weeklyShiftId == 2);
      target = admin.clinics.last.id;
    });

    test('una consulta nueva tras la vista previa se rechaza sin cambiar', () {
      final original = booked.clinicId;
      // La vista previa mostró 2; entra una consulta más antes de guardar.
      db.agendadasPorTurno[booked.id] = 3;

      expect(
        () => db.changeClinic(
          2,
          target,
          turnoIds: [booked.id],
          confirmarConConsultas: true,
          consultasAgendadasVistas: 2,
        ),
        throwsA(
          isA<ShiftNotModifiableException>().having(
            (e) => e.message,
            'message',
            kClinicChangeBookedMessage,
          ),
        ),
      );
      expect(booked.clinicId, original);

      db.changeClinic(
        2,
        target,
        turnoIds: [booked.id],
        confirmarConConsultas: true,
        consultasAgendadasVistas: 3,
      );
      expect(booked.clinicId, target);
    });

    test('con menos consultas que las vistas también se rechaza', () {
      final original = booked.clinicId;

      expect(
        () => db.changeClinic(
          2,
          target,
          turnoIds: [booked.id],
          confirmarConConsultas: true,
          consultasAgendadasVistas: 3,
        ),
        throwsA(isA<ShiftNotModifiableException>()),
      );
      expect(booked.clinicId, original);
    });

    test('con el total visto correcto el cambio se aplica', () {
      db.changeClinic(
        2,
        target,
        turnoIds: [booked.id],
        confirmarConConsultas: true,
        consultasAgendadasVistas: 2,
      );

      expect(booked.clinicId, target);
      expect(db.agendadasPorTurno[booked.id], 2);
    });

    test('el total visto suma todas las fechas elegidas', () {
      final other = db.shifts.firstWhere(
        (shift) => shift.weeklyShiftId == 2 && shift.id != booked.id,
      );
      db.agendadasPorTurno[other.id] = 1;

      expect(
        () => db.changeClinic(
          2,
          target,
          turnoIds: [booked.id, other.id],
          confirmarConConsultas: true,
          consultasAgendadasVistas: 2,
        ),
        throwsA(isA<ShiftNotModifiableException>()),
      );
      expect(booked.clinicId, isNot(target));

      db.changeClinic(
        2,
        target,
        turnoIds: [booked.id, other.id],
        confirmarConConsultas: true,
        consultasAgendadasVistas: 3,
      );
      expect(booked.clinicId, target);
      expect(other.clinicId, target);
    });

    test('una fecha elegida que ya usa el destino también cuenta', () {
      final other = db.shifts.firstWhere(
        (shift) => shift.weeklyShiftId == 2 && shift.id != booked.id,
      );
      other.clinicId = target;
      db.agendadasPorTurno[other.id] = 1;

      db.changeClinic(
        2,
        target,
        turnoIds: [booked.id, other.id],
        confirmarConConsultas: true,
        consultasAgendadasVistas: 3,
      );

      expect(booked.clinicId, target);
    });

    test('sin confirmación el total visto se ignora', () {
      final free = db.shifts.firstWhere(
        (shift) => shift.weeklyShiftId == 1 && shift.state == ShiftState.active,
      );

      db.changeClinic(
        1,
        target,
        turnoIds: [free.id],
        consultasAgendadasVistas: 99,
      );

      expect(free.clinicId, target);
      // Con consultas y sin confirmar sigue el rechazo de siempre.
      expect(
        () => db.changeClinic(
          2,
          target,
          turnoIds: [booked.id],
          consultasAgendadasVistas: 2,
        ),
        throwsA(isA<ShiftNotModifiableException>()),
      );
    });

    test('con confirmación y sin total visto se comporta como antes', () {
      db.agendadasPorTurno[booked.id] = 5;

      db.changeClinic(
        2,
        target,
        turnoIds: [booked.id],
        confirmarConConsultas: true,
      );

      expect(booked.clinicId, target);
    });
  });

  test('dos cambios parciales terminan actualizando el patrón', () {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 11, 10, 15),
    );
    final db = FakeShiftDatabase(admin);
    final pattern = db.weeklyShifts.first;
    final target = admin.clinics.last.id;
    final dates = db.shifts
        .where((shift) => shift.weeklyShiftId == pattern.id)
        .toList();
    expect(dates.length, greaterThan(1));

    db.changeClinic(pattern.id, target, turnoIds: [dates.first.id]);
    final result = db.changeClinic(
      pattern.id,
      target,
      turnoIds: dates.skip(1).map((date) => date.id).toList(),
      confirmarConConsultas: true,
    );

    expect(dates.every((date) => date.clinicId == target), isTrue);
    expect(result.clinic.id, target);
    expect(result.clinicVariesByDate, isFalse);
  });

  test('rechaza IDs de otro patrón y selecciones vacías', () {
    final admin = FakeAdminDatabase(
      clock: () => DateTime.utc(2026, 11, 10, 15),
    );
    final db = FakeShiftDatabase(admin);
    final other = db.shifts.firstWhere((shift) => shift.weeklyShiftId == 2);

    const text =
        'No pudimos aplicar el cambio. Actualizá la vista previa e intentá de '
        'nuevo.';
    Matcher invalid() => isA<ShiftValidationException>()
        .having((e) => e.message, 'message', text)
        .having((e) => e.message, 'sin turnoIds', isNot(contains('turnoIds')));

    expect(
      () => db.changeClinic(1, admin.clinics.last.id, turnoIds: [other.id]),
      throwsA(invalid()),
    );
    expect(
      () => db.changeClinic(1, admin.clinics.last.id, turnoIds: []),
      throwsA(invalid()),
    );
    expect(() => db.previewClinicChange(0, 1), throwsA(invalid()));
  });
}
