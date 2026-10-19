import '../../../core/network/api_exception.dart';
import '../models/doctor.dart';
import '../models/new_weekly_shift.dart';
import '../models/shift_filters.dart';
import '../models/shift_page.dart';
import '../models/weekly_shift.dart';

abstract class ShiftRepository {
  /// Médicos activos, ordenados por apellido y nombre. Con [specialtyId], solo
  /// los que ejercen esa especialidad.
  Future<List<Doctor>> listDoctors({int? specialtyId});

  /// Da de alta el turno semanal y genera un turno por cada fecha del período.
  /// No crea nada si falla alguna regla.
  Future<WeeklyShift> createWeeklyShift(NewWeeklyShift data);

  Future<WeeklyShift> getWeeklyShift(int id);

  /// Una página de fechas concretas de turnos (RF-17), con los filtros, el
  /// orden y la paginación resueltos del lado del servidor.
  Future<ShiftPage> listShifts(ShiftFilters filters);
}

/// Un dato que no cumple las reglas (`VALIDACION`, 400).
class ShiftValidationException extends ApiException {
  const ShiftValidationException(super.message);

  String get code => 'VALIDACION';
}

/// La especialidad no es una de las del médico
/// (`ESPECIALIDAD_NO_DEL_MEDICO`, 400).
class SpecialtyNotOfDoctorException extends ApiException {
  const SpecialtyNotOfDoctorException([
    super.message =
        'La especialidad elegida no es una de las del médico. '
        'Elegí otra especialidad o cambiá de médico.',
  ]);

  String get code => 'ESPECIALIDAD_NO_DEL_MEDICO';
}

/// El médico no está activo (`MEDICO_INACTIVO`, 409).
class InactiveDoctorException extends ApiException {
  const InactiveDoctorException([
    super.message =
        'El médico elegido no está activo, así que no se le pueden '
        'asignar turnos. Elegí otro médico.',
  ]);

  String get code => 'MEDICO_INACTIVO';
}

/// El médico o el consultorio no existen (`NO_ENCONTRADO`, 404).
class ShiftNotFoundException extends ApiException {
  const ShiftNotFoundException([
    super.message =
        'No encontramos lo que buscabas. Puede que ya no exista: '
        'volvé al listado y probá de nuevo.',
  ]);

  String get code => 'NO_ENCONTRADO';
}

/// Algún número se cruza con un turno activo del mismo médico o consultorio
/// (`SOLAPAMIENTO_TURNO`, 409). El [message] nombra las fechas y los números.
class OverlappingShiftException extends ApiException {
  const OverlappingShiftException(super.message);

  String get code => 'SOLAPAMIENTO_TURNO';
}
