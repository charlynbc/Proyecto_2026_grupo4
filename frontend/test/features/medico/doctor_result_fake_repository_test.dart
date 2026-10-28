import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/medico/models/doctor_appointment_result.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_result_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_result_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Con la semilla de FakeAdminDatabase: 1 Medicina General, 2 Cardiología y
// 3 Dermatología.
const _cardiology = 2;

FakeDoctorResultRepository _fake() =>
    FakeDoctorResultRepository(FakeAdminDatabase(), latency: Duration.zero);

void main() {
  test(
    'las constantes fijas del fake son la especialidad 3 y la consulta 99',
    () {
      expect(kFakeDuplicateReferralSpecialtyId, 3);
      expect(kFakeNotTodayAppointmentId, 99);
    },
  );

  test('ATENDIDA devuelve atencionId y un pase por cada pase pedido', () async {
    final result = await _fake().register(
      15,
      const AppointmentResultRequest(
        outcome: ConsultationOutcome.attended,
        condition: 'gripe',
        referrals: [
          ReferralRequest(specialtyId: _cardiology, validityDays: 30),
        ],
      ),
    );

    expect(result.appointmentId, 15);
    expect(result.outcome, ConsultationOutcome.attended);
    expect(result.attentionId, 1015);
    expect(result.referrals, hasLength(1));
    expect(result.referrals.single.id, 1);
    expect(result.referrals.single.specialty.name, 'Cardiología');
    expect(
      result.referrals.single.expiresOn,
      UruguayTime.today().add(const Duration(days: 30)),
    );
  });

  test('NO_SE_PRESENTO devuelve atencionId nulo y ningún pase', () async {
    final result = await _fake().register(
      15,
      const AppointmentResultRequest(outcome: ConsultationOutcome.noShow),
    );

    expect(result.outcome, ConsultationOutcome.noShow);
    expect(result.attentionId, isNull);
    expect(result.referrals, isEmpty);
  });

  test('pedir la especialidad 3 responde PASE_DUPLICADO', () async {
    await expectLater(
      _fake().register(
        15,
        const AppointmentResultRequest(
          outcome: ConsultationOutcome.attended,
          condition: 'gripe',
          referrals: [ReferralRequest(specialtyId: 3)],
        ),
      ),
      throwsA(isA<DuplicateReferralException>()),
    );
  });

  test('la consulta 99 responde CONSULTA_NO_ES_DE_HOY', () async {
    await expectLater(
      _fake().register(
        99,
        const AppointmentResultRequest(outcome: ConsultationOutcome.noShow),
      ),
      throwsA(isA<AppointmentNotTodayException>()),
    );
  });

  test('una especialidad que no existe responde VALIDACION', () async {
    await expectLater(
      _fake().register(
        15,
        const AppointmentResultRequest(
          outcome: ConsultationOutcome.attended,
          condition: 'gripe',
          referrals: [ReferralRequest(specialtyId: 77)],
        ),
      ),
      throwsA(isA<ResultValidationException>()),
    );
  });
}
