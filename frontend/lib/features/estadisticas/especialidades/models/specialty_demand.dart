import '../../../agenda/models/agenda_time.dart';
import '../../../especialidades/models/specialty.dart';

/// Una especialidad con la cantidad de consultas agendadas en el período.
class SpecialtyDemandItem {
  const SpecialtyDemandItem({required this.specialty, required this.count});

  final Specialty specialty;
  final int count;

  factory SpecialtyDemandItem.fromJson(Map<String, dynamic> json) =>
      SpecialtyDemandItem(
        specialty: Specialty.fromJson(
          json['especialidad'] as Map<String, dynamic>,
        ),
        count: json['cantidadConsultas'] as int,
      );
}

/// La respuesta de `GET /api/estadisticas/especialidades` (RF-39).
class SpecialtyDemand {
  const SpecialtyDemand({
    required this.from,
    required this.to,
    required this.items,
  });

  /// Primer y último día del período, como claves de día en UTC.
  final DateTime from;
  final DateTime to;

  /// En el orden que manda el servidor.
  final List<SpecialtyDemandItem> items;

  int get total => items.fold(0, (sum, item) => sum + item.count);

  factory SpecialtyDemand.fromJson(Map<String, dynamic> json) =>
      SpecialtyDemand(
        from: parseApiDate(json['desde'] as String),
        to: parseApiDate(json['hasta'] as String),
        items: [
          for (final item in json['items'] as List<dynamic>)
            SpecialtyDemandItem.fromJson(item as Map<String, dynamic>),
        ],
      );
}
