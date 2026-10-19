import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_shift_database.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/shift_state.dart';
import 'package:agenda_medica/features/turnos/repositories/shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ShiftNumber n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

FakeAccount doctorNamed(FakeAdminDatabase admin, String lastName) => admin
    .accounts
    .firstWhere((a) => a.role == UserRole.medico && a.lastName == lastName);

void main() {
  late FakeAdminDatabase admin;
  late FakeShiftDatabase db;
  late FakeAccount mendez; // Medicina General, activa.
  late FakeAccount acosta; // Medicina General y Dermatología, activa.
  late FakeAccount silva; // Cardiología, activa.
  late FakeAccount pereira; // Cuenta de médico inactivada.
  late int clinicA;
  late int clinicB;

  // 20/10/2026 es martes: hasta el 10/11 hay cuatro martes.
  NewWeeklyShift request({
    FakeAccount? doctor,
    int specialtyId = 1,
    int? clinicId,
    int weekday = 2,
    DateTime? startDate,
    DateTime? endDate,
    List<ShiftNumber>? numbers,
  }) => NewWeeklyShift(
    doctorId: (doctor ?? mendez).id,
    specialtyId: specialtyId,
    clinicId: clinicId ?? clinicA,
    weekday: weekday,
    startDate: startDate ?? DateTime.utc(2026, 10, 20),
    endDate: endDate ?? DateTime.utc(2026, 11, 10),
    numbers: numbers ?? [n(1, '09:00', '09:20'), n(2, '09:20', '09:40')],
  );

  setUp(() {
    admin = FakeAdminDatabase();
    db = FakeShiftDatabase(admin, seed: false);
    mendez = doctorNamed(admin, 'Méndez');
    acosta = doctorNamed(admin, 'Acosta');
    silva = doctorNamed(admin, 'Silva');
    pereira = admin.accounts.firstWhere(
      (a) =>
          a.role == UserRole.medico &&
          a.lastName == 'Pereira' &&
          a.status.name == 'inactive',
    );
    clinicA = admin.clinics[0].id;
    clinicB = admin.clinics[1].id;
  });

  group('generación de los turnos concretos', () {
    test('crea un turno por cada fecha del día elegido en el período', () {
      final created = db.createWeeklyShift(request());
      final dates = db.shifts
          .where((s) => s.weeklyShiftId == created.id)
          .map((s) => s.date)
          .toList();
      expect(dates, [
        DateTime.utc(2026, 10, 20),
        DateTime.utc(2026, 10, 27),
        DateTime.utc(2026, 11, 3),
        DateTime.utc(2026, 11, 10),
      ]);
      expect(created.shiftCount, 4);
    });

    test('diaSemana 1 es lunes', () {
      final created = db.createWeeklyShift(request(weekday: 1));
      final dates = db.shifts
          .where((s) => s.weeklyShiftId == created.id)
          .map((s) => s.date)
          .toList();
      expect(dates, [
        DateTime.utc(2026, 10, 26),
        DateTime.utc(2026, 11, 2),
        DateTime.utc(2026, 11, 9),
      ]);
      expect(dates.every((d) => d.weekday == DateTime.monday), isTrue);
    });

    test('diaSemana 7 es domingo', () {
      final created = db.createWeeklyShift(request(weekday: 7));
      final dates = db.shifts
          .where((s) => s.weeklyShiftId == created.id)
          .map((s) => s.date)
          .toList();
      expect(dates, [
        DateTime.utc(2026, 10, 25),
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 11, 8),
      ]);
    });

    test('las fechas de inicio y de fin cuentan si caen en ese día', () {
      final created = db.createWeeklyShift(
        request(
          startDate: DateTime.utc(2026, 10, 20),
          endDate: DateTime.utc(2026, 10, 20),
        ),
      );
      expect(created.shiftCount, 1);
    });

    test('cada turno concreto lleva su horario, sus números y el estado', () {
      final created = db.createWeeklyShift(
        request(
          numbers: [n(1, '09:00', '09:20'), n(2, '10:00', '10:30')],
          clinicId: clinicB,
        ),
      );
      final shifts = db.shifts.where((s) => s.weeklyShiftId == created.id);
      expect(shifts.map((s) => s.id).toSet().length, shifts.length);
      for (final shift in shifts) {
        expect(shift.startMinutes, ShiftNumber.parseTime('09:00'));
        expect(shift.endMinutes, ShiftNumber.parseTime('10:30'));
        expect(shift.numbers.length, 2);
        expect(shift.state, ShiftState.active);
        expect(shift.weekday, 2);
        expect(shift.doctorId, mendez.id);
        expect(shift.specialtyId, 1);
        expect(shift.clinicId, clinicB);
      }
    });
  });

  // Decisión: el mensaje de cruce nombra los números del pedido nuevo (los
  // que el funcionario puede corregir), no los del turno que ya existía.
  group('cruces con turnos activos', () {
    setUp(() {
      // Martes 20/10, 27/10, 3/11 y 10/11, de 09:00 a 09:40, Méndez, consultorio A.
      db.createWeeklyShift(request());
    });

    test('el mismo médico en otro consultorio: cruce de médico', () {
      final before = db.shifts.length;
      expect(
        () => db.createWeeklyShift(
          request(clinicId: clinicB, numbers: [n(1, '09:30', '09:50')]),
        ),
        throwsA(
          isA<OverlappingShiftException>()
              .having((e) => e.message, 'message', contains('20/10/2026'))
              .having((e) => e.message, 'message', contains('27/10/2026'))
              .having((e) => e.message, 'message', contains('03/11/2026'))
              .having((e) => e.message, 'message', contains('10/11/2026'))
              .having((e) => e.message, 'message', contains('número 1'))
              .having((e) => e.message, 'message', contains('médico'))
              .having(
                (e) => e.message,
                'message',
                isNot(contains('consultorio')),
              ),
        ),
      );
      expect(db.shifts.length, before, reason: 'no se crea nada');
    });

    test('el mismo consultorio con otro médico: cruce de consultorio', () {
      expect(
        () => db.createWeeklyShift(
          request(doctor: acosta, numbers: [n(1, '09:00', '09:20')]),
        ),
        throwsA(
          isA<OverlappingShiftException>()
              .having((e) => e.message, 'message', contains('20/10/2026'))
              .having((e) => e.message, 'message', contains('número 1'))
              .having((e) => e.message, 'message', contains('consultorio'))
              .having((e) => e.message, 'message', isNot(contains('médico'))),
        ),
      );
    });

    // Decisión: si el cruce es con el médico y con el consultorio a la vez, el
    // mensaje dice "del médico y del consultorio"; si solo es de uno, nombra
    // solo ese. Se junta lo de todas las fechas y números en conflicto.
    test('el mismo médico y el mismo consultorio: nombra ambos', () {
      expect(
        () => db.createWeeklyShift(request(numbers: [n(1, '09:10', '09:30')])),
        throwsA(
          isA<OverlappingShiftException>()
              .having(
                (e) => e.message,
                'message',
                contains('del médico y del consultorio'),
              )
              .having((e) => e.message, 'message', contains('20/10/2026'))
              .having((e) => e.message, 'message', contains('número 1')),
        ),
      );
    });

    test('un cruce de médico y otro de consultorio en números distintos', () {
      // Acosta ocupa el consultorio B los martes de 11:00 a 11:20.
      db.createWeeklyShift(
        request(
          doctor: acosta,
          clinicId: clinicB,
          numbers: [n(1, '11:00', '11:20')],
        ),
      );
      // El número 1 pisa a Méndez (09:00 en A); el 2 pisa el consultorio B.
      expect(
        () => db.createWeeklyShift(
          request(
            clinicId: clinicB,
            numbers: [n(1, '09:10', '09:30'), n(2, '11:00', '11:20')],
          ),
        ),
        throwsA(
          isA<OverlappingShiftException>()
              .having(
                (e) => e.message,
                'message',
                contains('del médico y del consultorio'),
              )
              .having((e) => e.message, 'message', contains('números 1 y 2')),
        ),
      );
    });

    test('nombra todos los números en conflicto', () {
      expect(
        () => db.createWeeklyShift(
          request(
            clinicId: clinicB,
            numbers: [n(1, '09:00', '09:10'), n(2, '09:20', '09:30')],
          ),
        ),
        throwsA(
          isA<OverlappingShiftException>().having(
            (e) => e.message,
            'message',
            contains('números 1 y 2'),
          ),
        ),
      );
    });

    test('solo nombra las fechas que se cruzan', () {
      // Desde el 3/11 en adelante: se cruza el 3/11 y el 10/11, no el 20/10.
      expect(
        () => db.createWeeklyShift(
          request(
            clinicId: clinicB,
            startDate: DateTime.utc(2026, 11, 3),
            endDate: DateTime.utc(2026, 11, 17),
          ),
        ),
        throwsA(
          isA<OverlappingShiftException>()
              .having((e) => e.message, 'message', contains('03/11/2026'))
              .having((e) => e.message, 'message', contains('10/11/2026'))
              .having(
                (e) => e.message,
                'message',
                isNot(contains('20/10/2026')),
              )
              .having(
                (e) => e.message,
                'message',
                isNot(contains('17/11/2026')),
              ),
        ),
      );
    });

    test('números que solo se tocan en el extremo no se cruzan', () {
      final created = db.createWeeklyShift(
        request(numbers: [n(1, '09:40', '10:00')]),
      );
      expect(created.shiftCount, 4);
    });

    test('otro día de la semana, otro horario u otros médico y consultorio no se cruzan', () {
      db.createWeeklyShift(request(weekday: 3));
      db.createWeeklyShift(request(numbers: [n(1, '11:00', '11:20')]));
      db.createWeeklyShift(request(doctor: acosta, clinicId: clinicB));
      expect(db.shifts.length, 4 + 3 + 4 + 4);
    });
  });

  group('turnos suspendidos', () {
    test('un turno suspendido no genera cruce', () {
      final first = db.createWeeklyShift(request());
      for (final shift in db.shifts.where((s) => s.weeklyShiftId == first.id)) {
        db.suspendShift(shift.id);
      }
      expect(db.shifts.every((s) => s.state == ShiftState.suspended), isTrue);
      final second = db.createWeeklyShift(request());
      expect(second.shiftCount, 4);
    });

    test('solo cruza con las fechas que siguen activas', () {
      final first = db.createWeeklyShift(request());
      final firstShifts = db.shifts
          .where((s) => s.weeklyShiftId == first.id)
          .toList();
      // Quedan activos solo el 3/11 y el 10/11.
      db.suspendShift(firstShifts[0].id);
      db.suspendShift(firstShifts[1].id);
      expect(
        () => db.createWeeklyShift(request()),
        throwsA(
          isA<OverlappingShiftException>()
              .having((e) => e.message, 'message', contains('03/11/2026'))
              .having((e) => e.message, 'message', contains('10/11/2026'))
              .having(
                (e) => e.message,
                'message',
                isNot(contains('20/10/2026')),
              )
              .having(
                (e) => e.message,
                'message',
                isNot(contains('27/10/2026')),
              ),
        ),
      );
    });
  });

  group('validaciones', () {
    test('rechaza una vigencia sin ninguna fecha del día elegido', () {
      // Del miércoles 21/10 al viernes 23/10 no hay ningún martes.
      expect(
        () => db.createWeeklyShift(
          request(
            startDate: DateTime.utc(2026, 10, 21),
            endDate: DateTime.utc(2026, 10, 23),
          ),
        ),
        throwsA(
          isA<ShiftValidationException>()
              .having((e) => e.code, 'code', 'VALIDACION')
              .having((e) => e, 'es ApiException', isA<ApiException>())
              .having((e) => e.message, 'message', contains('21/10/2026'))
              .having((e) => e.message, 'message', contains('23/10/2026'))
              .having((e) => e.message, 'message', contains('martes')),
        ),
      );
      expect(db.shifts, isEmpty);
      expect(db.weeklyShifts, isEmpty);
    });

    test('rechaza una fecha de fin anterior a la de inicio', () {
      expect(
        () => db.createWeeklyShift(
          request(
            startDate: DateTime.utc(2026, 11, 10),
            endDate: DateTime.utc(2026, 10, 20),
          ),
        ),
        throwsA(
          isA<ShiftValidationException>().having(
            (e) => e.code,
            'code',
            'VALIDACION',
          ),
        ),
      );
    });

    test('rechaza una lista de números vacía', () {
      expect(
        () => db.createWeeklyShift(request(numbers: [])),
        throwsA(isA<ShiftValidationException>()),
      );
    });

    test('rechaza números que no cumplen las reglas', () {
      expect(
        () => db.createWeeklyShift(
          request(numbers: [n(1, '09:00', '09:20'), n(2, '09:10', '09:30')]),
        ),
        throwsA(isA<ShiftValidationException>()),
      );
      expect(
        () => db.createWeeklyShift(request(numbers: [n(1, '09:00', '09:05')])),
        throwsA(isA<ShiftValidationException>()),
      );
    });

    test('rechaza una especialidad que no es del médico', () {
      // Méndez solo ejerce Medicina General (1).
      expect(
        () => db.createWeeklyShift(request(specialtyId: 2)),
        throwsA(isA<SpecialtyNotOfDoctorException>()),
      );
      expect(
        () => db.createWeeklyShift(request(doctor: silva, specialtyId: 1)),
        throwsA(isA<SpecialtyNotOfDoctorException>()),
      );
      expect(db.shifts, isEmpty);
    });

    test('acepta cualquiera de las especialidades del médico', () {
      expect(
        db.createWeeklyShift(request(doctor: acosta, specialtyId: 3)).id,
        isPositive,
      );
    });

    test('rechaza un médico inactivo', () {
      expect(
        () => db.createWeeklyShift(request(doctor: pereira)),
        throwsA(isA<InactiveDoctorException>()),
      );
      expect(db.shifts, isEmpty);
    });

    test('un médico o consultorio que no existen no se encuentran', () {
      expect(
        () => db.createWeeklyShift(request(clinicId: 9999)),
        throwsA(isA<ShiftNotFoundException>()),
      );
      expect(
        () => db.createWeeklyShift(
          NewWeeklyShift(
            doctorId: 9999,
            specialtyId: 1,
            clinicId: clinicA,
            weekday: 2,
            startDate: DateTime.utc(2026, 10, 20),
            endDate: DateTime.utc(2026, 11, 10),
            numbers: [n(1, '09:00', '09:20')],
          ),
        ),
        throwsA(isA<ShiftNotFoundException>()),
      );
    });
  });

  group('FakeAdminDatabase', () {
    Map<String, Object?> snapshot() => {
      'specialties': admin.specialties.map((s) => s.id).toList(),
      'clinics': admin.clinics.map((c) => c.id).toList(),
      'accounts': [
        for (final a in admin.accounts)
          '${a.id}|${a.status.name}|${a.activated}|${a.specialtyIds}',
      ],
    };

    test('no se modifica al crear turnos, con o sin error', () {
      final before = snapshot();
      db.createWeeklyShift(request());
      expect(
        () => db.createWeeklyShift(request(clinicId: clinicB)),
        throwsA(isA<OverlappingShiftException>()),
      );
      expect(
        () => db.createWeeklyShift(request(specialtyId: 2)),
        throwsA(isA<SpecialtyNotOfDoctorException>()),
      );
      expect(snapshot(), before);
    });

    test('la base de turnos sembrada tampoco lo modifica', () {
      final before = snapshot();
      final seeded = FakeShiftDatabase(admin);
      expect(seeded.weeklyShifts, isNotEmpty);
      expect(seeded.shifts, isNotEmpty);
      expect(snapshot(), before);
    });
  });
}
