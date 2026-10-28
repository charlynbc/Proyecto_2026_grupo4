import '../../../core/network/api_exception.dart';

/// El turno no está suspendido o su fecha ya pasó (`TURNO_NO_REHABILITABLE`,
/// 409).
class ShiftNotReinstatableException extends ApiException {
  const ShiftNotReinstatableException([
    super.message =
        'Ese turno no se puede volver a habilitar: no está suspendido o la '
        'fecha ya pasó. Elegí otros turnos de la lista.',
  ]);

  String get code => 'TURNO_NO_REHABILITABLE';
}
