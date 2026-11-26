import '../../../core/fakes/fake_cancelable.dart';
import '../../../core/fakes/fake_database.dart';
import '../../../core/utils/uruguay_time.dart';
import '../models/appointment.dart';
import '../models/cancellation_result.dart';
import 'appointment_cancellation_repository.dart';

class FakeAppointmentCancellationRepository
    implements AppointmentCancellationRepository {
  FakeAppointmentCancellationRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FakeDatabase _db;
  final Duration latency;
  final DateTime Function() _clock;

  @override
  Future<CancellationResult> cancel(int id) async {
    await Future<void>.delayed(latency);

    final index = _db.appointments.indexWhere(
      (appointment) => appointment.id == id,
    );
    if (index == -1) {
      throw const CancellationException(
        CancellationFailure.notFound,
        'No se encontró la consulta.',
      );
    }

    final appointment = _db.appointments[index];
    final now = _clock().toUtc();
    // La regla (y el orden de los motivos) vive en `fakeCancelDenial`.
    switch (fakeCancelDenial(_db, appointment, now)) {
      case FakeCancelDenial.notScheduled:
        throw const CancellationException(
          CancellationFailure.notScheduled,
          'La consulta no está agendada.',
        );
      case FakeCancelDenial.alreadyArrived:
        throw const CancellationException(
          CancellationFailure.alreadyArrived,
          'El socio ya registró su llegada ese día',
        );
      case FakeCancelDenial.outsideWindow:
        throw const CancellationException(
          CancellationFailure.outsideWindow,
          'La cancelación debe solicitarse con al menos dos horas de anticipación.',
        );
      case null:
        break;
    }

    final uruguayNow = UruguayTime.toUruguay(now);
    final today = DateTime.utc(
      uruguayNow.year,
      uruguayNow.month,
      uruguayNow.day,
    );
    final referralReturned =
        appointment.referralId != null &&
        _db.referrals.any(
          (referral) =>
              referral.id == appointment.referralId &&
              !referral.expiresOn.isBefore(today),
        );

    final cancelled = Appointment(
      id: appointment.id,
      status: 'CANCELADA_SOCIO',
      date: appointment.date,
      number: appointment.number,
      startMinutes: appointment.startMinutes,
      endMinutes: appointment.endMinutes,
      doctor: appointment.doctor,
      specialty: appointment.specialty,
      clinic: appointment.clinic,
      referralId: appointment.referralId,
      bookedAt: appointment.bookedAt,
      cancelledAt: now,
      cancellationReason: appointment.cancellationReason,
      // Una consulta cancelada ya no se puede cancelar.
      cancelable: false,
    );
    _db.appointments[index] = cancelled;

    return CancellationResult(
      appointmentId: appointment.id,
      status: 'CANCELADA_SOCIO',
      cancelledAt: now,
      referralReturned: referralReturned,
    );
  }
}
