/// La respuesta de cancelar una consulta (`CancelacionConsultaDTO`).
///
/// Un `estado` distinto de `CANCELADA_INSTITUCION`, una fecha que falta o un
/// `paseDevuelto` que no es booleano tiran [FormatException] o [TypeError]. El
/// repositorio los convierte en el error genérico.
class DoctorCancellationResult {
  const DoctorCancellationResult({
    required this.appointmentId,
    required this.status,
    required this.cancelledAt,
    required this.referralReturned,
  });

  factory DoctorCancellationResult.fromJson(Map<String, dynamic> json) {
    final status = json['estado'] as String;
    if (status != 'CANCELADA_INSTITUCION') {
      throw const FormatException();
    }
    return DoctorCancellationResult(
      appointmentId: json['consultaId'] as int,
      status: status,
      cancelledAt: DateTime.parse(json['canceladaEn'] as String).toUtc(),
      referralReturned: json['paseDevuelto'] as bool,
    );
  }

  final int appointmentId;
  final String status;
  final DateTime cancelledAt;
  final bool referralReturned;
}
