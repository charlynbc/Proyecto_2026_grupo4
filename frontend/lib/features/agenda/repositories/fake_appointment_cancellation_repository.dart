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

  static const Duration _cancellationDeadline = Duration(hours: 2); 

  @override
  Future<CancellationResult> cancel(int id) async {
    await Future<void>.delayed(latency);

    final index = _db.appointments.indexWhere(
      (appointment) => appointment.id == id,
    );
    if (index == -1) {
      throw const CancellationException(
        CancellationFailure.notFound,
        'No se encontro la consulta.',
      );
    }

    final appointment = _db.appointments[index];
    if (appointment.status != 'AGENDADA') {
      throw const CancellationException(
        CancellationFailure.notScheduled,
        'La consulta no esta agendada.',
      );
    }

    final now = _clock().toUtc();
    final localStart = DateTime.utc(
      appointment.date.year,
      appointment.date.month,
      appointment.date.day,
      appointment.startMinutes ~/ 60,
      appointment.startMinutes % 60,
    );
    final uruguayStart = UruguayTime.toUruguay(localStart);
    final uruguayUtcDifference = localStart.difference(uruguayStart);
    final start = localStart.add(uruguayUtcDifference).toUtc();

    if (start.difference(now) < _cancellationDeadline) {
      throw const CancellationException(
        CancellationFailure.outsideWindow,
        'La cancelacion debe solicitarse con al menos dos horas de anticipacion.',
      );
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
