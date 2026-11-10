import '../../../agenda/models/agenda_time.dart';

/// Un grupo de la respuesta de `GET /api/estadisticas/inasistencias` (RF-42).
///
/// Con `agruparPor=MEDICO`, [id], [name] y [lastName] identifican al médico.
/// Con `ESPECIALIDAD`, [lastName] es null.
class AbsenceGroup {
  const AbsenceGroup({
    required this.id,
    required this.name,
    required this.lastName,
    required this.attended,
    required this.noShow,
    required this.missed,
    required this.notAttended,
    required this.total,
    required this.percentage,
    required this.percentageText,
  });

  final int id;
  final String name;
  final String? lastName;

  final int attended;
  final int noShow;
  final int missed;
  final int notAttended;
  final int total;

  /// El porcentaje que manda el servidor. `0` y `0.0` se leen igual.
  final double percentage;

  /// El texto de la tasa tal cual lo manda el servidor ("12 %" o "0 %").
  final String percentageText;

  factory AbsenceGroup.fromJson(Map<String, dynamic> json) => AbsenceGroup(
    id: json['id'] as int,
    name: json['nombre'] as String,
    lastName: json['apellido'] as String?,
    attended: json['atendidas'] as int,
    noShow: json['noAsistio'] as int,
    missed: json['noSePresento'] as int,
    notAttended: json['noAtendidas'] as int,
    total: json['total'] as int,
    percentage: (json['porcentajeInasistencia'] as num).toDouble(),
    percentageText: json['inasistencia'] as String,
  );
}

/// La respuesta de `GET /api/estadisticas/inasistencias` (RF-42).
class AbsenceStatistics {
  const AbsenceStatistics({
    required this.from,
    required this.to,
    required this.groupedBy,
    required this.items,
  });

  /// Primer y último día del período, como claves de día en UTC.
  final DateTime from;
  final DateTime to;

  /// `ESPECIALIDAD` o `MEDICO`, tal cual lo manda el servidor.
  final String groupedBy;

  /// En el orden que manda el servidor.
  final List<AbsenceGroup> items;

  factory AbsenceStatistics.fromJson(Map<String, dynamic> json) =>
      AbsenceStatistics(
        from: parseApiDate(json['desde'] as String),
        to: parseApiDate(json['hasta'] as String),
        groupedBy: json['agruparPor'] as String,
        items: [
          for (final item in json['items'] as List<dynamic>)
            AbsenceGroup.fromJson(item as Map<String, dynamic>),
        ],
      );
}
