/// Juego de datos de prueba coherente, usado por los repositories falsos
/// (`--dart-define=USE_FAKES=true`). No es parte del modelo de la app: son
/// solo datos fijos y un generador de turnos relativo a la fecha de hoy.
library;

/// Contraseña que acepta el login falso, para cualquier cédula de
/// [TestData.people].
const String kTestPassword = 'prueba1234';

/// Roles del sistema real.
const String kRoleMember = 'SOCIO';
const String kRoleStaff = 'FUNCIONARIO';
const String kRoleDoctor = 'MEDICO';
const String kRoleAdmin = 'ADMINISTRADOR';

class TestPerson {
  const TestPerson({required this.ci, required this.name, required this.role});

  final String ci;
  final String name;
  final String role;
}

class TestSpecialty {
  const TestSpecialty({
    required this.id,
    required this.name,
    required this.requiresReferral,
  });

  final int id;
  final String name;

  /// La especialidad exige un pase (`requiere_pase`).
  final bool requiresReferral;
}

class TestClinic {
  const TestClinic({required this.id, required this.name});

  final int id;
  final String name;
}

class TestDoctor {
  const TestDoctor({
    required this.id,
    required this.ci,
    required this.name,
    required this.specialtyId,
    required this.clinicId,
  });

  final int id;
  final String ci;
  final String name;
  final int specialtyId;
  final int clinicId;
}

/// Un número (cupo) de un turno: es lo que un socio reserva.
class TestNumber {
  const TestNumber({
    required this.id,
    required this.shiftId,
    required this.doctorId,
    required this.index,
    required this.start,
    required this.end,
  });

  final int id;
  final int shiftId;
  final int doctorId;

  /// Posición dentro del turno, desde 0.
  final int index;

  /// Instantes en UTC; se muestran en hora de Uruguay con `UruguayTime`.
  final DateTime start;
  final DateTime end;
}

/// Un turno: la franja de un médico en un consultorio, un día concreto.
class TestShift {
  const TestShift({
    required this.id,
    required this.doctorId,
    required this.clinicId,
    required this.start,
    required this.end,
    required this.numbers,
  });

  final int id;
  final int doctorId;
  final int clinicId;
  final DateTime start;
  final DateTime end;
  final List<TestNumber> numbers;
}

class TestData {
  TestData._();

  /// Una persona por rol, más los otros dos médicos. Todas las cédulas
  /// tienen dígito verificador válido.
  static const List<TestPerson> people = [
    TestPerson(ci: '12345672', name: 'Ana Rodríguez', role: kRoleMember),
    TestPerson(ci: '23456783', name: 'Bruno Pereira', role: kRoleStaff),
    TestPerson(ci: '34567894', name: 'Dra. Carla Méndez', role: kRoleDoctor),
    TestPerson(ci: '45678905', name: 'Diego Fernández', role: kRoleAdmin),
    TestPerson(ci: '56789016', name: 'Dr. Esteban Silva', role: kRoleDoctor),
    TestPerson(
      ci: '67890127',
      name: 'Dra. Florencia Acosta',
      role: kRoleDoctor,
    ),
  ];

  /// Dos de las cuatro exigen pase.
  static const List<TestSpecialty> specialties = [
    TestSpecialty(id: 1, name: 'Medicina general', requiresReferral: false),
    TestSpecialty(id: 2, name: 'Pediatría', requiresReferral: false),
    TestSpecialty(id: 3, name: 'Cardiología', requiresReferral: true),
    TestSpecialty(id: 4, name: 'Traumatología', requiresReferral: true),
  ];

  static const List<TestClinic> clinics = [
    TestClinic(id: 1, name: 'Consultorio 1'),
    TestClinic(id: 2, name: 'Consultorio 2'),
    TestClinic(id: 3, name: 'Consultorio 3'),
  ];

  static const List<TestDoctor> doctors = [
    TestDoctor(
      id: 1,
      ci: '34567894',
      name: 'Dra. Carla Méndez',
      specialtyId: 1,
      clinicId: 1,
    ),
    TestDoctor(
      id: 2,
      ci: '56789016',
      name: 'Dr. Esteban Silva',
      specialtyId: 3,
      clinicId: 2,
    ),
    TestDoctor(
      id: 3,
      ci: '67890127',
      name: 'Dra. Florencia Acosta',
      specialtyId: 2,
      clinicId: 3,
    ),
  ];

  /// Cada turno tiene cuatro números de media hora.
  static const int numbersPerShift = 4;
  static const int minutesPerNumber = 30;

  /// Semanas de turnos que se generan desde hoy.
  static const int weeks = 3;

  /// Franjas semanales: médico, día de la semana (`DateTime.monday` a
  /// `DateTime.sunday`), hora de inicio.
  static const List<({int doctorId, int weekday, int hour})> _weekly = [
    (doctorId: 1, weekday: DateTime.monday, hour: 8),
    (doctorId: 1, weekday: DateTime.wednesday, hour: 8),
    (doctorId: 2, weekday: DateTime.tuesday, hour: 14),
    (doctorId: 2, weekday: DateTime.thursday, hour: 14),
    (doctorId: 3, weekday: DateTime.monday, hour: 15),
    (doctorId: 3, weekday: DateTime.friday, hour: 9),
  ];

  /// Offset de Uruguay respecto de UTC, en horas (fijo, sin horario de
  /// verano).
  static const int _uruguayOffsetHours = 3;

  /// Los turnos de las próximas [weeks] semanas a partir de [today] (fecha
  /// de Uruguay como `DateTime.utc` sin hora, ver `UruguayTime.today`).
  /// Los ids son determinísticos para un mismo [today].
  static List<TestShift> shiftsFrom(DateTime today) {
    final shifts = <TestShift>[];
    var shiftId = 0;
    for (var offset = 0; offset < weeks * 7; offset++) {
      final day = DateTime.utc(today.year, today.month, today.day + offset);
      for (final slot in _weekly.where((w) => w.weekday == day.weekday)) {
        shiftId++;
        final doctor = doctors.firstWhere((d) => d.id == slot.doctorId);
        final start = DateTime.utc(
          day.year,
          day.month,
          day.day,
          slot.hour + _uruguayOffsetHours,
        );
        final numbers = List.generate(numbersPerShift, (i) {
          final numberStart = start.add(
            Duration(minutes: i * minutesPerNumber),
          );
          return TestNumber(
            id: shiftId * 100 + i,
            shiftId: shiftId,
            doctorId: doctor.id,
            index: i,
            start: numberStart,
            end: numberStart.add(const Duration(minutes: minutesPerNumber)),
          );
        });
        shifts.add(
          TestShift(
            id: shiftId,
            doctorId: doctor.id,
            clinicId: doctor.clinicId,
            start: start,
            end: numbers.last.end,
            numbers: numbers,
          ),
        );
      }
    }
    return shifts;
  }
}
