import 'package:agenda_medica/features/medico/repositories/doctor_patient_history_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_patient_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeDoctorPatientHistoryRepository repository;

  setUp(() {
    repository = FakeDoctorPatientHistoryRepository(latency: Duration.zero);
  });

  test('el socio 101 recibe sus dos atenciones en orden', () async {
    final entries = await repository.history(101);

    expect(entries, hasLength(2));
    final first = entries[0];
    expect(first.id, 5530);
    expect(first.attendedOn, DateTime.utc(2026, 10, 20));
    expect(first.doctorFullName, 'Marta Rodríguez');
    expect(first.specialty.name, 'Cardiología');
    expect(first.condition, 'Hipertensión arterial leve');
    expect(first.referrals, hasLength(1));
    expect(first.referrals.single.specialty.name, 'Nutrición');
    expect(first.referrals.single.expiresOn, DateTime.utc(2027, 1, 18));

    final second = entries[1];
    expect(second.id, 5000);
    expect(second.attendedOn, DateTime.utc(2026, 9, 10));
    expect(second.doctorFullName, 'Laura Pérez');
    expect(second.specialty.name, 'Traumatología');
    expect(second.condition, 'Dolor lumbar');
    expect(second.treatment, isNull);
    expect(second.referrals, isEmpty);
  });

  test('el socio 102 no tiene atenciones', () async {
    expect(await repository.history(102), isEmpty);
  });

  test('el socio 999 no encontrado lanza notFound', () async {
    await expectLater(
      repository.history(999),
      throwsA(
        isA<DoctorPatientHistoryException>().having(
          (error) => error.failure,
          'failure',
          DoctorPatientHistoryFailure.notFound,
        ),
      ),
    );
  });

  test('el id cero lanza validation', () async {
    await expectLater(
      repository.history(0),
      throwsA(
        isA<DoctorPatientHistoryException>().having(
          (error) => error.failure,
          'failure',
          DoctorPatientHistoryFailure.validation,
        ),
      ),
    );
  });

  test('el id negativo lanza validation', () async {
    await expectLater(
      repository.history(-3),
      throwsA(
        isA<DoctorPatientHistoryException>().having(
          (error) => error.failure,
          'failure',
          DoctorPatientHistoryFailure.validation,
        ),
      ),
    );
  });
}
