class CancellationResult {
  const CancellationResult({
    required this.appointmentId,
    required this.status,
    required this.cancelledAt,
    required this.referralReturned,
  });

  final int appointmentId;
  final String status;
  final DateTime cancelledAt;
  final bool referralReturned;

  factory CancellationResult.fromJson(Map<String, dynamic> json) {
    final status = json['estado'] as String;
    if (status != 'CANCELADA_SOCIO') {
      throw const FormatException();
    }
    return CancellationResult(
      appointmentId: json['consultaId'] as int,
      status: status,
      cancelledAt: DateTime.parse(json['canceladaEn'] as String).toUtc(),
      referralReturned: json['paseDevuelto'] as bool,
    );
  }
}
