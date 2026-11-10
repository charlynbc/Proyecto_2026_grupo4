class StaffCancellationResult {
  const StaffCancellationResult({
    required this.appointmentId,
    required this.status,
    required this.cancelledAt,
    required this.referralReturned,
  });

  final int appointmentId;
  final String status;
  final DateTime cancelledAt;
  final bool referralReturned;
}
