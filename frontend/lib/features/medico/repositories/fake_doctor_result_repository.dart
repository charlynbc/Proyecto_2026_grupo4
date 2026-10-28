import '../../../core/fakes/fake_admin_database.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/referral.dart';
import '../models/doctor_appointment_result.dart';
import 'doctor_result_repository.dart';

/// Pedir un pase a esta especialidad responde `PASE_DUPLICADO` (la 3 de la
/// semilla de [FakeAdminDatabase], Dermatología).
const int kFakeDuplicateReferralSpecialtyId = 3;

/// Registrar el resultado de esta consulta responde `CONSULTA_NO_ES_DE_HOY`.
const int kFakeNotTodayAppointmentId = 99;

/// Implementación en memoria para `USE_FAKES=true`. Nunca se usa contra la
/// API. Resuelve las especialidades de los pases con el catálogo de [_db].
class FakeDoctorResultRepository implements DoctorResultRepository {
  FakeDoctorResultRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
  });

  final FakeAdminDatabase _db;
  final Duration latency;
  int _nextReferralId = 1;

  /// El día de Uruguay de [instant], como clave de día en UTC.
  static DateTime _dayKey(DateTime instant) {
    final local = UruguayTime.toUruguay(instant);
    return DateTime.utc(local.year, local.month, local.day);
  }

  @override
  Future<AppointmentResult> register(
    int appointmentId,
    AppointmentResultRequest request,
  ) async {
    await Future<void>.delayed(latency);
    if (appointmentId == kFakeNotTodayAppointmentId) {
      throw const AppointmentNotTodayException();
    }
    final now = _db.clock();
    final today = _dayKey(now);
    if (request.outcome == ConsultationOutcome.noShow) {
      return AppointmentResult(
        appointmentId: appointmentId,
        outcome: ConsultationOutcome.noShow,
        attentionId: null,
        registeredAt: now,
        referrals: const [],
      );
    }
    final referrals = <Referral>[];
    for (final item in request.referrals) {
      if (item.specialtyId == kFakeDuplicateReferralSpecialtyId) {
        throw const DuplicateReferralException();
      }
      final specialty = _db.specialties
          .where((s) => s.id == item.specialtyId)
          .firstOrNull;
      if (specialty == null) throw const ResultValidationException();
      referrals.add(
        Referral(
          id: _nextReferralId++,
          specialty: specialty,
          issuedAt: now,
          expiresOn: today.add(Duration(days: item.validityDays)),
        ),
      );
    }
    return AppointmentResult(
      appointmentId: appointmentId,
      outcome: ConsultationOutcome.attended,
      attentionId: 1000 + appointmentId,
      registeredAt: now,
      referrals: referrals,
    );
  }
}
