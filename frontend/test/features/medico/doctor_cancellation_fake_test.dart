import 'package:agenda_medica/features/medico/models/doctor_shift.dart';
import 'package:agenda_medica/features/medico/repositories/doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_cancellation_repository.dart';
import 'package:agenda_medica/features/medico/repositories/fake_doctor_shift_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _validationMessage =
    'Revisá el motivo: es obligatorio y no puede superar los 1000 caracteres.';
const _notFoundMessage =
    'No encontramos esta consulta entre las tuyas. Se actualizó la lista.';
const _notScheduledMessage =
    'Esta consulta ya no está agendada, así que no se puede cancelar. '
    'Se actualizó la lista.';

final _clock = DateTime.utc(2026, 10, 30, 12, 3, 10);

Matcher _failure(DoctorCancellationFailure failure, String message) =>
    isA<DoctorCancellationException>()
        .having((e) => e.failure, 'failure', failure)
        .having((e) => e.message, 'message', message);

FakeDoctorCancellationRepository _repository(FakeDoctorShiftRepository shifts) {
  return FakeDoctorCancellationRepository(
    shifts,
    latency: Duration.zero,
    clock: () => _clock,
  );
}

void main() {
  test('cancelar la 10 libera el número 1 y baja el cupo a 1', () async {
    final shifts = FakeDoctorShiftRepository();
    final repository = _repository(shifts);

    final result = await repository.cancelAppointment(10, 'Imprevisto');

    expect(result.appointmentId, 10);
    expect(result.status, 'CANCELADA_INSTITUCION');
    expect(result.cancelledAt, _clock);
    expect(result.referralReturned, isFalse);

    final numbers = await shifts.listNumbers(1);
    expect(
      numbers.items[0],
      const DoctorShiftNumber(
        numberId: 1,
        number: 1,
        startTime: '09:00',
        endTime: '09:20',
      ),
    );
    expect(numbers.items[1].appointmentId, 11);
    expect(numbers.items[1].patient!.name, 'Luis');
    final listed = await shifts.listShifts('2026-10-30');
    expect(listed.single.reservedCount, 1);
    expect(listed.single.numbersCount, 3);
  });

  test('cancelar la 11 libera el número 2 y baja el cupo a 1', () async {
    final shifts = FakeDoctorShiftRepository();
    final repository = _repository(shifts);

    final result = await repository.cancelAppointment(11, 'Imprevisto');

    expect(result.appointmentId, 11);
    expect(result.status, 'CANCELADA_INSTITUCION');
    expect(result.cancelledAt, _clock);
    expect(result.referralReturned, isFalse);

    final numbers = await shifts.listNumbers(1);
    expect(numbers.items[0].appointmentId, 10);
    expect(numbers.items[0].patient!.name, 'Ana');
    expect(
      numbers.items[1],
      const DoctorShiftNumber(
        numberId: 2,
        number: 2,
        startTime: '09:20',
        endTime: '09:40',
      ),
    );
    final listed = await shifts.listShifts('2026-10-30');
    expect(listed.single.reservedCount, 1);
    expect(listed.single.numbersCount, 3);
  });

  test(
    'cancelar la 10 de nuevo es una consulta que ya no está agendada',
    () async {
      final shifts = FakeDoctorShiftRepository();
      final repository = _repository(shifts);
      await repository.cancelAppointment(10, 'Imprevisto');

      await expectLater(
        repository.cancelAppointment(10, 'Imprevisto'),
        throwsA(
          _failure(
            DoctorCancellationFailure.notScheduled,
            _notScheduledMessage,
          ),
        ),
      );
      final listed = await shifts.listShifts('2026-10-30');
      expect(listed.single.reservedCount, 1);
    },
  );

  test('el id 77 no es una consulta del turno', () async {
    final shifts = FakeDoctorShiftRepository();
    final repository = _repository(shifts);

    await expectLater(
      repository.cancelAppointment(77, 'Imprevisto'),
      throwsA(_failure(DoctorCancellationFailure.notFound, _notFoundMessage)),
    );
    final listed = await shifts.listShifts('2026-10-30');
    expect(listed.single.reservedCount, 2);
  });

  test('el motivo vacío es validación y no cancela', () async {
    final shifts = FakeDoctorShiftRepository();
    final repository = _repository(shifts);

    await expectLater(
      repository.cancelAppointment(10, ''),
      throwsA(
        _failure(DoctorCancellationFailure.validation, _validationMessage),
      ),
    );
    final numbers = await shifts.listNumbers(1);
    expect(numbers.items[0].appointmentId, 10);
    final listed = await shifts.listShifts('2026-10-30');
    expect(listed.single.reservedCount, 2);
  });

  test('el id 0 es validación y no cancela', () async {
    final shifts = FakeDoctorShiftRepository();
    final repository = _repository(shifts);

    await expectLater(
      repository.cancelAppointment(0, 'Imprevisto'),
      throwsA(
        _failure(DoctorCancellationFailure.validation, _validationMessage),
      ),
    );
    final listed = await shifts.listShifts('2026-10-30');
    expect(listed.single.reservedCount, 2);
  });

  test('un motivo de 1001 caracteres es validación y no cancela', () async {
    final shifts = FakeDoctorShiftRepository();
    final repository = _repository(shifts);

    await expectLater(
      repository.cancelAppointment(10, 'a' * 1001),
      throwsA(
        _failure(DoctorCancellationFailure.validation, _validationMessage),
      ),
    );
    final numbers = await shifts.listNumbers(1);
    expect(numbers.items[0].appointmentId, 10);
  });
}
