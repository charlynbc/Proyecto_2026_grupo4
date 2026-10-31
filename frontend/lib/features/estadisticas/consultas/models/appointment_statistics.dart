import '../../../agenda/models/agenda_time.dart';

/// Los siete estados de una consulta, en el orden fijo de la pantalla.
const List<String> kStatisticsStatusOrder = [
  'AGENDADA',
  'ATENDIDA',
  'CANCELADA_SOCIO',
  'CANCELADA_INSTITUCION',
  'NO_ASISTIO',
  'NO_ATENDIDA',
  'NO_SE_PRESENTO',
];

/// La etiqueta en español de un estado de [kStatisticsStatusOrder]. Un estado
/// desconocido tira `FormatException`, en vez de mostrarse sin avisar.
String statisticsStatusLabel(String key) => switch (key) {
  'AGENDADA' => 'Agendada',
  'ATENDIDA' => 'Atendida',
  'CANCELADA_SOCIO' => 'Cancelada por el socio',
  'CANCELADA_INSTITUCION' => 'Cancelada por la institución',
  'NO_ASISTIO' => 'No asistió',
  'NO_ATENDIDA' => 'No atendida',
  'NO_SE_PRESENTO' => 'No se presentó a la consulta',
  _ => throw FormatException('Estado de consulta desconocido', key),
};

/// La respuesta de `GET /api/estadisticas/consultas` (RF-41).
class AppointmentStatistics {
  const AppointmentStatistics({
    required this.from,
    required this.to,
    required this.counts,
    required this.total,
    required this.cancelledBySocio,
    required this.percentage,
    required this.percentageText,
  });

  /// Primer y último día del período, como claves de día en UTC.
  final DateTime from;
  final DateTime to;

  /// Cantidad de consultas por estado, con las claves de
  /// [kStatisticsStatusOrder].
  final Map<String, int> counts;

  /// El total que manda el servidor (no se suma acá).
  final int total;
  final int cancelledBySocio;

  /// `null` cuando el total es cero.
  final double? percentage;

  /// El texto de la tasa tal cual lo manda el servidor ("10 %" o
  /// "Sin datos").
  final String percentageText;

  factory AppointmentStatistics.fromJson(Map<String, dynamic> json) {
    final states = json['estados'] as Map<String, dynamic>;
    // Siempre vienen los siete; uno de más o de menos es un error, no algo
    // que se ignore.
    if (states.length != kStatisticsStatusOrder.length ||
        !states.keys.every(kStatisticsStatusOrder.contains)) {
      throw FormatException(
        'Estados de consulta inesperados',
        states.keys.toList(),
      );
    }
    return AppointmentStatistics(
      from: parseApiDate(json['desde'] as String),
      to: parseApiDate(json['hasta'] as String),
      counts: {
        for (final key in kStatisticsStatusOrder) key: states[key] as int,
      },
      total: json['totalConsultas'] as int,
      cancelledBySocio: json['canceladasPorSocio'] as int,
      // El servidor puede mandar `10` o `10.0`.
      percentage: (json['porcentajeCancelacion'] as num?)?.toDouble(),
      percentageText: json['porcentajeCancelacionTexto'] as String,
    );
  }
}
