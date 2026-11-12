import '../../../core/network/api_exception.dart';
import '../models/weekly_shift.dart';
import '../models/clinic_change_preview.dart';

/// Cambia el consultorio de una configuración semanal (fila 51).
abstract class WeeklyShiftClinicRepository {
  /// Consulta sin modificar los turnos de hoy en adelante.
  Future<ClinicChangePreview> previewClinicChange(
    int weeklyShiftId,
    int clinicId,
  );

  /// Devuelve la configuración resultante. El consultorio actual es un no-op.
  Future<WeeklyShift> changeClinic(
    int weeklyShiftId,
    int clinicId, {
    List<int>? turnoIds,
    bool confirmarConConsultas = false,
  });
}

/// Textos propios del cambio de consultorio. El servidor manda mensajes con
/// fechas aaaa-mm-dd, listas entre corchetes y nombres de campos; el usuario
/// ve estos (RNF-16 y RNF-23).
const String kClinicChangeOverlapMessage =
    'Alguna de las fechas elegidas se superpone con otro turno del consultorio '
    'nuevo. Revisá la vista previa y desmarcá esas fechas.';
const String kClinicChangeBookedMessage =
    'Hay consultas agendadas en las fechas elegidas. Revisá la vista previa y '
    'confirmá el cambio para continuar.';
const String kClinicChangeInvalidMessage =
    'No pudimos aplicar el cambio. Actualizá la vista previa e intentá de '
    'nuevo.';

/// El turno no se puede modificar (`TURNO_NO_MODIFICABLE`, 409).
class ShiftNotModifiableException extends ApiException {
  const ShiftNotModifiableException([
    super.message =
        'Hay fechas con consultas agendadas. Confirmá expresamente el cambio '
        'para continuar, o elegí otras fechas.',
  ]);

  String get code => 'TURNO_NO_MODIFICABLE';
}
