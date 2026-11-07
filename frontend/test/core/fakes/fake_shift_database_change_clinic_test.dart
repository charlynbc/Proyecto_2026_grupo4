import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/features/consultorios/models/clinic.dart';
import 'package:agenda_medica/features/especialidades/models/specialty.dart';
import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:agenda_medica/features/turnos/repositories/weekly_shift_clinic_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _invalid = 'Faltan datos obligatorios o no son válidos';
const _missingShift = 'No existe el turno semanal indicado';
const _missingClinic = 'No existe el consultorio indicado';
const _finished =
    'El turno semanal ya finalizó; no tiene fechas actuales ni futuras '
    'por modificar';
const _twoAppointments =
    'El turno tiene 2 consulta(s) agendada(s) en fechas vigentes. '
    'Suspenda las fechas correspondientes (RF-14) y dé de alta otro turno.';
const _overlap =
    'Se encontraron solapamientos: fecha 2026-10-20, número 1 con número '
    'existente 1';

/// Hoy en el reloj fijo: 20/10/2026, mediodía en Uruguay.
final _today = DateTime.utc(2026, 10, 20);
final _past = DateTime.utc(2026, 10, 13);
final _future = DateTime.utc(2026, 10, 27);
final _later = DateTime.utc(2026, 11, 3);

ShiftNumber _n(String start, String end) => ShiftNumber(
  number: 1,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

void main() {
  late FakeAdminDatabase admin;
  late FakeShiftDatabase db;
  late Clinic room3;
  late Clinic room7;
  late Specialty specialty;

  setUp(() {
    admin = FakeAdminDatabase(clock: () => DateTime.utc(2026, 10, 20, 15));
    db = FakeShiftDatabase(admin, seed: false);
    room3 = admin.clinics.firstWhere((c) => c.name == 'Consultorio 3');
    room7 = admin.clinics.firstWhere((c) => c.name == 'Consultorio 7');
    specialty = admin.specialties.first;
  });

  WeeklyShift plant({
    required int id,
    required int doctorId,
    required Clinic clinic,
    required List<ShiftNumber> numbers,
    required List<FakeShift> dates,
  }) {
    final weekly = WeeklyShift(
      id: id,
      doctor: DoctorRef(id: doctorId, firstName: 'Carla', lastName: 'Méndez'),
      specialty: specialty,
      clinic: clinic,
      weekday: 2,
      startDate: _past,
      endDate: _later,
      numbers: numbers,
      shiftCount: dates.length,
    );
    db.weeklyShifts.add(weekly);
    db.shifts.addAll(dates);
    return weekly;
  }

  FakeShift date({
    required int id,
    required int weeklyShiftId,
    required DateTime day,
    required int clinicId,
    required int doctorId,
    required List<ShiftNumber> numbers,
  }) {
    return FakeShift(
      id: id,
      weeklyShiftId: weeklyShiftId,
      date: day,
      weekday: 2,
      startMinutes: numbers.first.startMinutes,
      endMinutes: numbers.first.endMinutes,
      numbers: numbers,
      doctorId: doctorId,
      specialtyId: specialty.id,
      clinicId: clinicId,
    );
  }

  test('un id inválido no cambia nada', () {
    expect(
      () => db.changeClinic(0, room7.id),
      throwsA(
        isA<ShiftValidationException>().having(
          (e) => e.message,
          'message',
          _invalid,
        ),
      ),
    );
    expect(
      () => db.changeClinic(1, 0),
      throwsA(
        isA<ShiftValidationException>().having(
          (e) => e.message,
          'message',
          _invalid,
        ),
      ),
    );
  });

  test('una configuración que no existe no cambia nada', () {
    expect(
      () => db.changeClinic(40, room7.id),
      throwsA(
        isA<ShiftNotFoundException>().having(
          (e) => e.message,
          'message',
          _missingShift,
        ),
      ),
    );
  });

  test('el mismo consultorio se devuelve sin cambios', () {
    final numbers = [_n('09:00', '09:20')];
    plant(
      id: 1,
      doctorId: 10,
      clinic: room3,
      numbers: numbers,
      dates: [
        date(
          id: 1,
          weeklyShiftId: 1,
          day: _future,
          clinicId: room3.id,
          doctorId: 10,
          numbers: numbers,
        ),
      ],
    );

    final returned = db.changeClinic(1, room3.id);

    expect(returned.clinic.id, room3.id);
    expect(returned.clinic.name, 'Consultorio 3');
    expect(db.weeklyShiftById(1)!.clinic.id, room3.id);
    expect(db.shifts.single.clinicId, room3.id);
  });

  test('un consultorio que no existe no cambia nada', () {
    final numbers = [_n('09:00', '09:20')];
    plant(
      id: 1,
      doctorId: 10,
      clinic: room3,
      numbers: numbers,
      dates: [
        date(
          id: 1,
          weeklyShiftId: 1,
          day: _future,
          clinicId: room3.id,
          doctorId: 10,
          numbers: numbers,
        ),
      ],
    );

    expect(
      () => db.changeClinic(1, 99),
      throwsA(
        isA<ShiftNotFoundException>().having(
          (e) => e.message,
          'message',
          _missingClinic,
        ),
      ),
    );
    expect(db.weeklyShiftById(1)!.clinic.id, room3.id);
    expect(db.shifts.single.clinicId, room3.id);
  });

  test('sin fechas de hoy en adelante no cambia nada', () {
    final numbers = [_n('09:00', '09:20')];
    plant(
      id: 1,
      doctorId: 10,
      clinic: room3,
      numbers: numbers,
      dates: [
        date(
          id: 1,
          weeklyShiftId: 1,
          day: _past,
          clinicId: room3.id,
          doctorId: 10,
          numbers: numbers,
        ),
      ],
    );

    expect(
      () => db.changeClinic(1, room7.id),
      throwsA(
        isA<ShiftNotModifiableException>().having(
          (e) => e.message,
          'message',
          _finished,
        ),
      ),
    );
    expect(db.weeklyShiftById(1)!.clinic.name, 'Consultorio 3');
    expect(db.shifts.single.clinicId, room3.id);
  });

  test('con 2 consultas agendadas no cambia nada', () {
    final numbers = [_n('09:00', '09:20')];
    plant(
      id: 1,
      doctorId: 10,
      clinic: room3,
      numbers: numbers,
      dates: [
        date(
          id: 1,
          weeklyShiftId: 1,
          day: _future,
          clinicId: room3.id,
          doctorId: 10,
          numbers: numbers,
        ),
      ],
    );
    db.agendadasPorTurnoSemanal[1] = 2;

    expect(
      () => db.changeClinic(1, room7.id),
      throwsA(
        isA<ShiftNotModifiableException>().having(
          (e) => e.message,
          'message',
          _twoAppointments,
        ),
      ),
    );
    expect(db.weeklyShiftById(1)!.clinic.name, 'Consultorio 3');
    expect(db.shifts.single.clinicId, room3.id);
  });

  test('un cruce de 09:10-09:30 contra 09:00-09:20 no cambia nada', () {
    final moving = [_n('09:10', '09:30')];
    final existing = [_n('09:00', '09:20')];
    plant(
      id: 1,
      doctorId: 10,
      clinic: room3,
      numbers: moving,
      dates: [
        date(
          id: 1,
          weeklyShiftId: 1,
          day: _today,
          clinicId: room3.id,
          doctorId: 10,
          numbers: moving,
        ),
      ],
    );
    plant(
      id: 2,
      doctorId: 20,
      clinic: room7,
      numbers: existing,
      dates: [
        date(
          id: 2,
          weeklyShiftId: 2,
          day: _today,
          clinicId: room7.id,
          doctorId: 20,
          numbers: existing,
        ),
      ],
    );

    expect(
      () => db.changeClinic(1, room7.id),
      throwsA(
        isA<OverlappingShiftException>().having(
          (e) => e.message,
          'message',
          _overlap,
        ),
      ),
    );
    expect(db.weeklyShiftById(1)!.clinic.name, 'Consultorio 3');
    expect(db.shifts.first.clinicId, room3.id);
    expect(db.shifts.last.clinicId, room7.id);
  });

  test(
    'pasadas quedan, hoy y futuras cambian, la suspendida sigue suspendida',
    () {
      final numbers = [_n('09:00', '09:20')];
      plant(
        id: 1,
        doctorId: 10,
        clinic: room3,
        numbers: numbers,
        dates: [
          date(
            id: 1,
            weeklyShiftId: 1,
            day: _past,
            clinicId: room3.id,
            doctorId: 10,
            numbers: numbers,
          ),
          date(
            id: 2,
            weeklyShiftId: 1,
            day: _today,
            clinicId: room3.id,
            doctorId: 10,
            numbers: numbers,
          ),
          date(
            id: 3,
            weeklyShiftId: 1,
            day: _future,
            clinicId: room3.id,
            doctorId: 10,
            numbers: numbers,
          ),
          date(
            id: 4,
            weeklyShiftId: 1,
            day: _later,
            clinicId: room3.id,
            doctorId: 10,
            numbers: numbers,
          ),
        ],
      );
      db.suspendShift(4);

      final returned = db.changeClinic(1, room7.id);

      expect(returned.clinic.name, 'Consultorio 7');
      expect(returned.clinic.location, 'Piso 1');
      expect(db.weeklyShiftById(1)!.clinic.id, room7.id);
      expect(db.shifts[0].clinicId, room3.id);
      expect(db.shifts[0].date, _past);
      expect(db.shifts[1].clinicId, room7.id);
      expect(db.shifts[1].state, ShiftState.active);
      expect(db.shifts[2].clinicId, room7.id);
      expect(db.shifts[3].clinicId, room7.id);
      expect(db.shifts[3].state, ShiftState.suspended);
    },
  );
}
