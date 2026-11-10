import '../models/staff_cancellation_result.dart';

abstract class StaffCancellationRepository {
  Future<StaffCancellationResult> cancel(int id);
}

enum StaffCancellationFailure {
  notFound,
  notScheduled,
  outsideWindow,
  conflictOfInterest,
  validation,
  unauthenticated,
  forbidden,
  other,
}

class StaffCancellationException implements Exception {
  const StaffCancellationException(this.failure, this.message);

  final StaffCancellationFailure failure;
  final String message;

  @override
  String toString() => message;
}
