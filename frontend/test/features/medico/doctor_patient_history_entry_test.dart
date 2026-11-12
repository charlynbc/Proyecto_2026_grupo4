import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _numberJson({bool includePatientId = true}) {
  final patient = <String, dynamic>{
    'ci': '12345678',
    'nombre': 'Ana',
    'apellido': 'Pérez',
    if (includePatientId) 'id': 101,
  };
  return {
    'numeroId': 3201,
    'numero': 1,
    'horaInicio': '09:00:00',
    'horaFin': '09:20:00',
    'consulta': {'id': 5501, 'estado': 'AGENDADA', 'paciente': patient},
  };
}

void main() {
  group('DoctorShiftNumber.fromJson', () {
    test('lee el id del paciente en la consulta', () {
      final number = DoctorShiftNumber.fromJson(_numberJson());

      expect(number.patient!.id, 101);
    });

    test('acepta paciente sin id y conserva sus otros datos', () {
      final number = DoctorShiftNumber.fromJson(
        _numberJson(includePatientId: false),
      );

      expect(number.patient!.id, isNull);
      expect(number.patient!.ci, '12345678');
      expect(number.patient!.name, 'Ana');
      expect(number.patient!.lastName, 'Pérez');
      expect(number.appointmentId, 5501);
      expect(number.appointmentStatus, 'AGENDADA');
    });
  });

  group('igualdad de DoctorPatient', () {
    test('pacientes con distinto id no son iguales', () {
      const first = DoctorPatient(
        id: 101,
        ci: '12345678',
        name: 'Ana',
        lastName: 'Pérez',
      );
      const second = DoctorPatient(
        id: 102,
        ci: '12345678',
        name: 'Ana',
        lastName: 'Pérez',
      );

      expect(first == second, isFalse);
    });

    test('pacientes con el mismo id son iguales y tienen el mismo hash', () {
      const first = DoctorPatient(
        id: 101,
        ci: '12345678',
        name: 'Ana',
        lastName: 'Pérez',
      );
      const second = DoctorPatient(
        id: 101,
        ci: '12345678',
        name: 'Ana',
        lastName: 'Pérez',
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });
  });

  test('la agenda falsa identifica a Ana Pérez y Luis Gómez por id', () async {
    final repository = FakeDoctorShiftRepository();
    final shifts = await repository.listShifts('2026-10-30');
    final numbers = await repository.listNumbers(shifts.single.id);
    final ana = numbers.items.firstWhere(
      (number) => number.patient?.name == 'Ana',
    );
    final luis = numbers.items.firstWhere(
      (number) => number.patient?.name == 'Luis',
    );

    expect(ana.patient!.lastName, 'Pérez');
    expect(ana.patient!.id, 101);
    expect(luis.patient!.lastName, 'Gómez');
    expect(luis.patient!.id, 102);
  });
}
