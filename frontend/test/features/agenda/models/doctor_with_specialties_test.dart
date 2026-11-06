import 'package:agenda_medica/features/agenda/models/doctor_with_specialties.dart';
import 'package:flutter_test/flutter_test.dart';

// Los ejemplos del contrato para GET /api/medicos (#10): una lista JSON sin
// envoltorio. El del socio trae solo id y nombre en cada especialidad.
const _forMember = [
  {
    'id': 17,
    'nombre': 'Marta',
    'apellido': 'Rodríguez',
    'especialidades': [
      {'id': 1, 'nombre': 'Medicina General'},
      {'id': 3, 'nombre': 'Cardiología'},
    ],
  },
];

const _forStaff = [
  {
    'id': 17,
    'nombre': 'Marta',
    'apellido': 'Rodríguez',
    'especialidades': [
      {'id': 1, 'nombre': 'Medicina General', 'requierePase': false},
      {'id': 3, 'nombre': 'Cardiología', 'requierePase': true},
    ],
  },
];

void main() {
  group('doctorsFromJson', () {
    test('lee la lista sin envoltorio del socio', () {
      final doctors = doctorsFromJson(_forMember);

      expect(doctors, hasLength(1));
      final doctor = doctors.single;
      expect(doctor.id, 17);
      expect(doctor.firstName, 'Marta');
      expect(doctor.lastName, 'Rodríguez');
      expect(doctor.specialties.map((s) => s.id), [1, 3]);
      expect(doctor.specialties.map((s) => s.name), [
        'Medicina General',
        'Cardiología',
      ]);
    });

    test('lee también la respuesta del funcionario, con requierePase', () {
      final doctor = doctorsFromJson(_forStaff).single;

      expect(doctor.specialties.map((s) => s.id), [1, 3]);
    });

    test('tolera el envoltorio items', () {
      final doctors = doctorsFromJson({'items': _forMember});

      expect(doctors.map((d) => d.id), [17]);
    });

    test('una lista vacía es una lista vacía', () {
      expect(doctorsFromJson(<Object>[]), isEmpty);
    });

    test('un cuerpo que no es lista ni objeto es un error de formato', () {
      expect(() => doctorsFromJson('hola'), throwsFormatException);
      expect(() => doctorsFromJson(null), throwsFormatException);
    });

    test('attends dice si el médico ejerce la especialidad', () {
      final doctor = doctorsFromJson(_forMember).single;

      expect(doctor.attends(3), isTrue);
      expect(doctor.attends(2), isFalse);
    });
  });
}
