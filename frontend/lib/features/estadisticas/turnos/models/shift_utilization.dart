import '../../../agenda/models/agenda_time.dart';
import '../../../agenda/models/available_number.dart';
import '../../../consultorios/models/clinic.dart';
import '../../../especialidades/models/specialty.dart';

/// Un turno semanal con su utilización en el período (RF-40).
class ShiftUtilizationItem {
  const ShiftUtilizationItem({
    required this.shiftId,
    required this.doctor,
    required this.specialty,
    required this.clinic,
    required this.weekday,
    required this.activeDates,
    required this.offered,
    required this.occupied,
    required this.percentage,
    required this.utilization,
  });

  final int shiftId;
  final DoctorRef doctor;
  final Specialty specialty;
  final Clinic clinic;

  /// De 1 (lunes) a 7 (domingo).
  final int weekday;

  /// Cuántas fechas del turno estuvieron activas en el período.
  final int activeDates;

  /// Números ofrecidos y ocupados en esas fechas.
  final int offered;
  final int occupied;

  /// `null` cuando no hubo números ofrecidos.
  final double? percentage;

  /// El texto que manda el servidor ("75 %" o "Sin datos"), tal cual.
  final String utilization;

  factory ShiftUtilizationItem.fromJson(Map<String, dynamic> json) {
    final weekday = json['diaSemana'] as int;
    if (weekday < 1 || weekday > 7) {
      throw FormatException('Día de la semana fuera de rango', weekday);
    }
    return ShiftUtilizationItem(
      shiftId: json['turnoSemanalId'] as int,
      doctor: DoctorRef.fromJson(json['medico'] as Map<String, dynamic>),
      specialty: Specialty.fromJson(
        json['especialidad'] as Map<String, dynamic>,
      ),
      clinic: Clinic.fromJson(json['consultorio'] as Map<String, dynamic>),
      weekday: weekday,
      activeDates: json['fechasActivas'] as int,
      offered: json['numerosOfrecidos'] as int,
      occupied: json['numerosOcupados'] as int,
      // El servidor puede mandar `100` o `75.0`.
      percentage: (json['porcentajeUtilizacion'] as num?)?.toDouble(),
      utilization: json['utilizacion'] as String,
    );
  }
}

/// La respuesta de `GET /api/estadisticas/turnos`.
class ShiftUtilization {
  const ShiftUtilization({
    required this.from,
    required this.to,
    required this.items,
  });

  /// Primer y último día del período, como claves de día en UTC.
  final DateTime from;
  final DateTime to;

  /// En el orden que manda el servidor.
  final List<ShiftUtilizationItem> items;

  factory ShiftUtilization.fromJson(Map<String, dynamic> json) =>
      ShiftUtilization(
        from: parseApiDate(json['desde'] as String),
        to: parseApiDate(json['hasta'] as String),
        items: [
          for (final item in json['items'] as List<dynamic>)
            ShiftUtilizationItem.fromJson(item as Map<String, dynamic>),
        ],
      );
}
