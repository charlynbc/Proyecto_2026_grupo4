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
  group('reloj del proyecto', () {
    // 2026-10-27 02:00 UTC son las 23:00 del 26/10 en Uruguay.
    final lateNight = DateTime.utc(2026, 10, 27, 2);

    FakeDoctorResultRepository fakeAt(DateTime now) =>
        FakeDoctorResultRepository(
          FakeAdminDatabase(clock: () => now),
          latency: Duration.zero,
        );

    test('registeredAt e issuedAt son el instante del reloj', () async {
      final result = await fakeAt(lateNight).register(
        15,
        const AppointmentResultRequest(
          outcome: ConsultationOutcome.attended,
          condition: 'gripe',
          referrals: [ReferralRequest(specialtyId: _cardiology)],
        ),
      );

      expect(result.registeredAt, DateTime.utc(2026, 10, 27, 2));
      expect(result.referrals.single.issuedAt, DateTime.utc(2026, 10, 27, 2));
    });

    test(
      'el vencimiento cuenta desde el día de Uruguay, no el de UTC',
      () async {
        final result = await fakeAt(lateNight).register(
          15,
          const AppointmentResultRequest(
            outcome: ConsultationOutcome.attended,
            condition: 'gripe',
            referrals: [ReferralRequest(specialtyId: _cardiology)],
          ),
        );

        // 26/10/2026 más 90 días es el 24/01/2027.
        expect(result.referrals.single.expiresOn, DateTime.utc(2027, 1, 24));
      },
    );

    test('NO_SE_PRESENTO también usa el reloj', () async {
      final result = await fakeAt(lateNight).register(
        15,
        const AppointmentResultRequest(outcome: ConsultationOutcome.noShow),
      );

      expect(result.registeredAt, DateTime.utc(2026, 10, 27, 2));
    });
  });

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
