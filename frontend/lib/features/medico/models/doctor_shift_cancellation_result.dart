import '../../agenda/models/agenda_time.dart';

class DoctorShiftCancellationResult {
  const DoctorShiftCancellationResult({
    required this.shiftId,
    required this.date,
    required this.status,
    required this.cancelledCount,
    required this.returnedReferralsCount,
  });

  factory DoctorShiftCancellationResult.fromJson(Map<String, dynamic> json) {
    final id = json['turnoId'] as int;
    final status = json['estado'] as String;
    final cancelled = json['consultasCanceladas'] as int;
    final referrals = json['pasesDevueltos'] as int;
    if (id <= 0 || status != 'SUSPENDIDO' || cancelled < 0 || referrals < 0) {
      throw const FormatException();
    }
    return DoctorShiftCancellationResult(
      shiftId: id,
      date: parseApiDate(json['fecha'] as String),
      status: status,
      cancelledCount: cancelled,
      returnedReferralsCount: referrals,
    );
  }

  final int shiftId;
  final DateTime date;
  final String status;
  final int cancelledCount;
  final int returnedReferralsCount;
}
