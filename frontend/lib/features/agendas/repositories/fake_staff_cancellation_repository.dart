import 'staff_cancellation_repository.dart';
import '../models/staff_cancellation_result.dart';
import 'fake_schedule_repository.dart';
import '../../../core/utils/uruguay_time.dart';

class FakeStaffCancellationRepository implements StaffCancellationRepository {
  FakeStaffCancellationRepository(
    this._schedules, {
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FakeScheduleRepository _schedules;
  final Duration latency;
  final DateTime Function() _clock;

  static const Duration _cancellationDeadline = Duration(hours: 2);

  @override
  Future<StaffCancellationResult> cancel(int id) async {
    if (id <= 0) {
      throw const StaffCancellationException(
        StaffCancellationFailure.validation,
        'La consulta indicada no es válida.',
      );
    }

    await Future<void>.delayed(latency);

    final entry = _schedules.findById(id);
    if (entry == null) {
      throw const StaffCancellationException(
        StaffCancellationFailure.notFound,
        'No se encontró la consulta.',
      );
    }
    if (entry.status != 'AGENDADA') {
      throw const StaffCancellationException(
        StaffCancellationFailure.notScheduled,
        'La consulta no está agendada.',
      );
    }

    final now = _clock().toUtc();
    final localStart = DateTime.utc(
      entry.date.year,
      entry.date.month,
      entry.date.day,
      entry.startMinutes ~/ 60,
      entry.startMinutes % 60,
    );
    final uruguayStart = UruguayTime.toUruguay(localStart);
    final uruguayUtcDifference = localStart.difference(uruguayStart);
    final start = localStart.add(uruguayUtcDifference).toUtc();

    if (start.difference(now) < _cancellationDeadline) {
      throw const StaffCancellationException(
        StaffCancellationFailure.outsideWindow,
        'La cancelación debe solicitarse con al menos dos horas de anticipación.',
      );
    }

    _schedules.markCancelled(id);

    /// paseDevuelto es una simplificación del Fake.
    return StaffCancellationResult(
      appointmentId: id,
      status: 'CANCELADA_SOCIO',
      cancelledAt: now,
      referralReturned: entry.specialty.requiresReferral,
    );
  }
}
