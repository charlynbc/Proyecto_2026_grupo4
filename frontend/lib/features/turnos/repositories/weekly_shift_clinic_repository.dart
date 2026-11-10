import '../../../core/network/api_exception.dart';
import '../models/weekly_shift.dart';
import '../models/clinic_change_preview.dart';

/// Cambia el consultorio de una configuración semanal (fila 51).
abstract class WeeklyShiftClinicRepository {
  /// Consulta sin modificar los turnos de hoy en adelante.
  Future<ClinicChangePreview> previewClinicChange(int weeklyShiftId, int clinicId);

  /// Devuelve la configuración resultante. El consultorio actual es un no-op.
  Future<WeeklyShift> changeClinic(int weeklyShiftId, int clinicId);
}

/// El turno no se puede modificar (`TURNO_NO_MODIFICABLE`, 409).
class ShiftNotModifiableException extends ApiException {
  const ShiftNotModifiableException([
    super.message =
        'No se puede cambiar el consultorio de este turno. Si tiene '
        'consultas agendadas, suspendé esas fechas y dá de alta otro turno.',
  ]);

  String get code => 'TURNO_NO_MODIFICABLE';
}
