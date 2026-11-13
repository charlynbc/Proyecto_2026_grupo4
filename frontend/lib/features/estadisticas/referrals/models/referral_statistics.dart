import '../../../agenda/models/agenda_time.dart';

class ReferralItem {
  const ReferralItem({
    required this.name,
    required this.issued,
    required this.used,
    required this.available,
    required this.expired,
    required this.percentage,
    required this.utilization,
  });
  final String name;
  final int issued, used, available, expired;
  final double? percentage;
  final String utilization;

  factory ReferralItem.fromJson(Map<String, dynamic> json) => ReferralItem(
    name:
        (json['especialidadDestino'] as Map<String, dynamic>)['nombre']
            as String,
    issued: json['emitidos'] as int,
    used: json['utilizados'] as int,
    available: json['disponibles'] as int,
    expired: json['vencidos'] as int,
    percentage: (json['porcentajeUtilizados'] as num?)?.toDouble(),
    utilization: json['utilizacion'] as String,
  );
}

class ReferralStatistics {
  const ReferralStatistics({
    required this.from,
    required this.to,
    required this.items,
  });
  final DateTime from, to;
  final List<ReferralItem> items;
  factory ReferralStatistics.fromJson(Map<String, dynamic> json) =>
      ReferralStatistics(
        from: parseApiDate(json['desde'] as String),
        to: parseApiDate(json['hasta'] as String),
        items: [
          for (final item in json['items'] as List<dynamic>)
            ReferralItem.fromJson(item as Map<String, dynamic>),
        ],
      );
}
