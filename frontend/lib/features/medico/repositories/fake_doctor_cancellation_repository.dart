import '../models/doctor_cancellation_result.dart';
import '../models/doctor_shift_cancellation_result.dart';
import '../../../core/utils/uruguay_time.dart';
import 'doctor_cancellation_repository.dart';
import 'fake_doctor_shift_repository.dart';

/// Las únicas consultas agendadas del turno falso.
const _scheduledIds = {10, 11};

/// Cancelación en memoria. No modela el plazo de 2 horas ni el conflicto de
/// interés: eso se prueba contra el repositorio real y con uno escrito a mano.
class FakeDoctorCancellationRepository implements DoctorCancellationRepository {
  FakeDoctorCancellationRepository(
    this._shifts, {
    this.latency = const Duration(milliseconds: 300),
    required this.clock,
  });

  final FakeDoctorShiftRepository _shifts;
  final Duration latency;
  final DateTime Function() clock;

  @override
  Future<DoctorShiftCancellationResult> cancelShift(
    int shiftId,
    String reason,
  ) async {
    await Future<void>.delayed(latency);
    final trimmed = reason.trim();
    DoctorCancellationException error(DoctorCancellationFailure failure) =>
        DoctorCancellationException(failure, cancelShiftMessage(failure));
    if (shiftId <= 0 || trimmed.isEmpty || trimmed.length > 1000) {
      throw error(DoctorCancellationFailure.validation);
    }
    if (shiftId != 1) throw error(DoctorCancellationFailure.notFound);
    if (_shifts.isSuspended) {
      throw error(DoctorCancellationFailure.shiftNotCancellable);
    }
    final count = _scheduledIds.where((id) => !_shifts.isCancelled(id)).length;
    _shifts.suspendShift(shiftId);
    return DoctorShiftCancellationResult(
      shiftId: shiftId,
      date: UruguayTime.today(),
      status: 'SUSPENDIDO',
      cancelledCount: count,
      returnedReferralsCount: 0,
    );
  }

  @override
  Future<DoctorCancellationResult> cancelAppointment(
    int appointmentId,
    String reason,
  ) async {
    await Future<void>.delayed(latency);
    final trimmed = reason.trim();
    if (appointmentId <= 0 || trimmed.isEmpty || trimmed.length > 1000) {
      throw _error(DoctorCancellationFailure.validation);
    }
    if (!_scheduledIds.contains(appointmentId)) {
      throw _error(DoctorCancellationFailure.notFound);
    }
    if (_shifts.isCancelled(appointmentId)) {
      throw _error(DoctorCancellationFailure.notScheduled);
    }
    _shifts.cancelAppointment(appointmentId);
    return DoctorCancellationResult(
      appointmentId: appointmentId,
      status: 'CANCELADA_INSTITUCION',
      cancelledAt: clock(),
      referralReturned: false,
    );
  }

  DoctorCancellationException _error(DoctorCancellationFailure failure) {
    return DoctorCancellationException(
      failure,
      cancelAppointmentMessage(failure),
    );
  }
}
