import 'shift_date_format.dart';
import 'shift_state.dart';

/// Resultado de la vista previa RF-20. No modifica ningún turno.
class ClinicChangePreview {
  const ClinicChangePreview({required this.dates});

  factory ClinicChangePreview.fromJson(Map<String, dynamic> json) =>
      ClinicChangePreview(
        dates: [
          for (final item in json['fechas'] as List<dynamic>)
            ClinicChangePreviewDate.fromJson(item as Map<String, dynamic>),
        ],
      );

  final List<ClinicChangePreviewDate> dates;
}

/// Una fecha concreta del patrón, identificada por turnoId, no por patrón.
class ClinicChangePreviewDate {
  const ClinicChangePreviewDate({
    required this.shiftId,
    required this.date,
    required this.state,
    required this.bookedAppointments,
    required this.overlaps,
    this.currentClinicId,
    this.currentClinicName,
  });

  factory ClinicChangePreviewDate.fromJson(Map<String, dynamic> json) {
    final currentClinic = json['consultorioActual'] as Map<String, dynamic>?;
    final appointments = json['consultasAgendadas'] as int;
    if (appointments < 0) {
      throw const FormatException('Cantidad de consultas negativa');
    }
    return ClinicChangePreviewDate(
      shiftId: json['turnoId'] as int,
      date: parseDateKey(json['fecha'] as String),
      state: ShiftState.fromApi(json['estado'] as String),
      bookedAppointments: appointments,
      overlaps: [
        for (final overlap in (json['solapamientos'] as List<dynamic>? ??
            const <dynamic>[]))
          ClinicChangeOverlap.fromJson(overlap as Map<String, dynamic>),
      ],
      currentClinicId: currentClinic?['id'] as int?,
      currentClinicName: currentClinic?['nombre'] as String?,
    );
  }

  final int shiftId;
  final DateTime date;
  final ShiftState state;
  final int bookedAppointments;
  final List<ClinicChangeOverlap> overlaps;

  /// Opcionales mientras se acuerda su inclusión en el contrato del backend.
  final int? currentClinicId;
  final String? currentClinicName;

  bool get hasOverlaps => overlaps.isNotEmpty;
  bool get requiresConfirmation => bookedAppointments > 0;
}

/// Indica qué número del turno propio choca con cuál del consultorio destino.
class ClinicChangeOverlap {
  const ClinicChangeOverlap({
    required this.ownNumber,
    required this.existingNumber,
  });

  factory ClinicChangeOverlap.fromJson(Map<String, dynamic> json) =>
      ClinicChangeOverlap(
        ownNumber: json['numeroPropio'] as int,
        existingNumber: json['numeroExistente'] as int,
      );

  final int ownNumber;
  final int existingNumber;
}
