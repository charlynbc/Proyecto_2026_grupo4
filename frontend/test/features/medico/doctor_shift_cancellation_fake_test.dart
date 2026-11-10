import 'package:agenda_medica/features/medico/repositories/doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_shift_repository.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancela consultas, suspende y libera los números', () async {
    final shifts = FakeDoctorShiftRepository();
    final repo = FakeDoctorCancellationRepository(
      shifts,
      latency: Duration.zero,
      clock: DateTime.now,
    );
    final before = UruguayTime.today();
    final result = await repo.cancelShift(1, 'Imprevisto');
    final after = UruguayTime.today();
    expect(result.date == before || result.date == after, isTrue);
    expect(result.returnedReferralsCount, 0);
    expect(result.cancelledCount, 2);
    expect((await shifts.listShifts('2099-01-01')).single.status, 'SUSPENDIDO');
    expect(
      (await shifts.listNumbers(1)).items.every((n) => !n.isReserved),
      isTrue,
    );
    await expectLater(
      repo.cancelShift(1, 'x'),
      throwsA(
        isA<DoctorCancellationException>().having(
          (e) => e.failure,
          'failure',
          DoctorCancellationFailure.shiftNotCancellable,
        ),
      ),
    );
  });
  test('cuenta solo consultas todavía agendadas', () async {
    final shifts = FakeDoctorShiftRepository();
    final repo = FakeDoctorCancellationRepository(
      shifts,
      latency: Duration.zero,
      clock: DateTime.now,
    );
    await repo.cancelAppointment(10, 'Motivo');
    expect((await repo.cancelShift(1, 'Motivo')).cancelledCount, 1);
  });
  test('valida el turno y el motivo', () async {
    final repo = FakeDoctorCancellationRepository(
      FakeDoctorShiftRepository(),
      latency: Duration.zero,
      clock: DateTime.now,
    );
    for (final (id, reason, failure) in [
      (0, 'x', DoctorCancellationFailure.validation),
      (1, ' ', DoctorCancellationFailure.validation),
      (1, 'a' * 1001, DoctorCancellationFailure.validation),
      (5, 'x', DoctorCancellationFailure.notFound),
    ]) {
      await expectLater(
        repo.cancelShift(id, reason),
        throwsA(
          isA<DoctorCancellationException>().having(
            (e) => e.failure,
            'failure',
            failure,
          ),
        ),
      );
    }
  });
}
