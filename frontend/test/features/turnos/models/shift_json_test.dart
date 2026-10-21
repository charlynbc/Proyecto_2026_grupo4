import 'package:agenda_medica/features/turnos/models/doctor.dart';
import 'package:agenda_medica/features/turnos/models/new_weekly_shift.dart';
import 'package:agenda_medica/features/turnos/models/shift_number.dart';
import 'package:agenda_medica/features/turnos/models/weekly_shift.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una respuesta mal formada falla con un error de tipo o con FormatException,
/// nunca devuelve un null silencioso.
final Matcher _malformed = throwsA(
  anyOf(isA<TypeError>(), isA<FormatException>()),
);

/// El `TurnoSemanalDTO` del contrato (#13 y #14).
Map<String, dynamic> weeklyShiftJson() => {
  'id': 120,
  'medico': {'id': 17, 'nombre': 'Marta', 'apellido': 'Rodríguez'},
  'especialidad': {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  'consultorio': {
    'id': 5,
    'nombre': 'Consultorio 5',
    'ubicacion': 'Piso 2, ala norte',
  },
  'diaSemana': 2,
  'fechaInicio': '2026-10-20',
  'fechaFin': '2026-12-15',
  'numeros': [
    {'numero': 1, 'horaInicio': '09:00', 'horaFin': '09:20'},
    {'numero': 2, 'horaInicio': '09:20', 'horaFin': '09:40'},
    {'numero': 3, 'horaInicio': '10:00', 'horaFin': '10:30'},
  ],
  'cantidadTurnos': 9,
};

/// El `MedicoDTO` de #10 del contrato.
Map<String, dynamic> doctorJson() => {
  'id': 17,
  'nombre': 'Marta',
  'apellido': 'Rodríguez',
  'especialidades': [
    {'id': 1, 'nombre': 'Medicina General', 'requierePase': false},
    {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
  ],
};

ShiftNumber _n(int number, String start, String end) => ShiftNumber(
  number: number,
  startMinutes: ShiftNumber.parseTime(start),
  endMinutes: ShiftNumber.parseTime(end),
);

void main() {
  group('NewWeeklyShift.toJson', () {
    NewWeeklyShift request({int weekday = 2, DateTime? start, DateTime? end}) =>
        NewWeeklyShift(
          doctorId: 17,
          specialtyId: 3,
          clinicId: 5,
          weekday: weekday,
          startDate: start ?? DateTime.utc(2026, 10, 20),
          endDate: end ?? DateTime.utc(2026, 12, 15),
          numbers: [
            _n(1, '09:00', '09:20'),
            _n(2, '09:20', '09:40'),
            _n(3, '10:00', '10:30'),
          ],
        );

    test('arma el AltaTurnoDTO del contrato', () {
      expect(request().toJson(), {
        'medicoId': 17,
        'especialidadId': 3,
        'consultorioId': 5,
        'diaSemana': 2,
        'fechaInicio': '2026-10-20',
        'fechaFin': '2026-12-15',
        'numeros': [
          {'numero': 1, 'horaInicio': '09:00', 'horaFin': '09:20'},
          {'numero': 2, 'horaInicio': '09:20', 'horaFin': '09:40'},
          {'numero': 3, 'horaInicio': '10:00', 'horaFin': '10:30'},
        ],
      });
    });

    test('diaSemana va de 1 (lunes) a 7 (domingo), sin transformarse', () {
      expect(request(weekday: 1).toJson()['diaSemana'], 1);
      expect(request(weekday: 7).toJson()['diaSemana'], 7);
    });

    test('las fechas llevan ceros: yyyy-MM-dd', () {
      final json = request(
        start: DateTime.utc(2026, 1, 5),
        end: DateTime.utc(2026, 2, 3),
      ).toJson();
      expect(json['fechaInicio'], '2026-01-05');
      expect(json['fechaFin'], '2026-02-03');
    });

    test('las horas son HH:mm, sin segundos', () {
      final numeros = request().toJson()['numeros'] as List<dynamic>;
      for (final number in numeros) {
        final map = number as Map<String, dynamic>;
        expect(map['horaInicio'], matches(RegExp(r'^\d{2}:\d{2}$')));
        expect(map['horaFin'], matches(RegExp(r'^\d{2}:\d{2}$')));
      }
    });
  });

  group('WeeklyShift.fromJson', () {
    test('lee un TurnoSemanalDTO del contrato', () {
      final weeklyShift = WeeklyShift.fromJson(weeklyShiftJson());

      expect(weeklyShift.id, 120);
      expect(weeklyShift.doctor.id, 17);
      expect(weeklyShift.doctor.firstName, 'Marta');
      expect(weeklyShift.doctor.lastName, 'Rodríguez');
      expect(weeklyShift.specialty.id, 3);
      expect(weeklyShift.specialty.name, 'Cardiología');
      expect(weeklyShift.specialty.requiresReferral, isTrue);
      expect(weeklyShift.clinic.id, 5);
      expect(weeklyShift.clinic.name, 'Consultorio 5');
      expect(weeklyShift.clinic.location, 'Piso 2, ala norte');
      expect(weeklyShift.weekday, 2);
      expect(weeklyShift.startDate, DateTime.utc(2026, 10, 20));
      expect(weeklyShift.endDate, DateTime.utc(2026, 12, 15));
      expect(weeklyShift.shiftCount, 9);
    });

    test('lee los números con su horario', () {
      final numbers = WeeklyShift.fromJson(weeklyShiftJson()).numbers;

      expect(numbers.map((n) => n.number), [1, 2, 3]);
      expect(numbers.last.startMinutes, 10 * 60);
      expect(numbers.last.endMinutes, 10 * 60 + 30);
      expect(numbers.last.duration, 30);
    });

    for (final key in [
      'id',
      'medico',
      'especialidad',
      'consultorio',
      'diaSemana',
      'fechaInicio',
      'fechaFin',
      'numeros',
      'cantidadTurnos',
    ]) {
      test('sin "$key" falla en vez de dar un null', () {
        final json = weeklyShiftJson()..remove(key);
        expect(() => WeeklyShift.fromJson(json), _malformed);
      });
    }

    test('el consultorio sin "ubicacion" falla: en el contrato no es nula', () {
      final json = weeklyShiftJson()
        ..['consultorio'] = {'id': 5, 'nombre': 'Consultorio 5'};
      expect(() => WeeklyShift.fromJson(json), _malformed);
    });

    test('una fecha que no es yyyy-MM-dd falla', () {
      final json = weeklyShiftJson()..['fechaInicio'] = '20/10/2026';
      expect(() => WeeklyShift.fromJson(json), throwsFormatException);
    });

    test('una hora con segundos falla', () {
      final json = weeklyShiftJson()
        ..['numeros'] = [
          {'numero': 1, 'horaInicio': '09:00:00', 'horaFin': '09:20'},
        ];
      expect(() => WeeklyShift.fromJson(json), throwsFormatException);
    });

    test('números que no son una lista fallan', () {
      final json = weeklyShiftJson()..['numeros'] = 'nada';
      expect(() => WeeklyShift.fromJson(json), _malformed);
    });
  });

  group('Doctor.fromJson', () {
    test('lee un médico con sus especialidades', () {
      final doctor = Doctor.fromJson(doctorJson());

      expect(doctor.id, 17);
      expect(doctor.firstName, 'Marta');
      expect(doctor.lastName, 'Rodríguez');
      expect(doctor.fullName, 'Marta Rodríguez');
      expect(doctor.specialties.map((s) => s.id), [1, 3]);
      expect(doctor.specialties.first.name, 'Medicina General');
      expect(doctor.specialties.first.requiresReferral, isFalse);
      expect(doctor.specialties.last.requiresReferral, isTrue);
    });

    test('un médico sin especialidades tiene una lista vacía', () {
      final json = doctorJson()..['especialidades'] = <Object>[];
      expect(Doctor.fromJson(json).specialties, isEmpty);
    });

    for (final key in ['id', 'nombre', 'apellido', 'especialidades']) {
      test('sin "$key" falla en vez de dar un null', () {
        final json = doctorJson()..remove(key);
        expect(() => Doctor.fromJson(json), _malformed);
      });
    }
  });
}
