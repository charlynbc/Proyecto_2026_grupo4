import '../../../core/network/api_exception.dart';
import '../models/suspension_filter.dart';
import '../models/suspension_preview.dart';
import '../models/suspension_result.dart';

/// Suspensión de fechas de turnos (RF-14).
abstract class ShiftSuspensionRepository {
  /// Lo que pasaría al suspender los turnos [ids]. No cambia nada.
  Future<SuspensionPreview> preview(List<int> ids);

  /// Suspende los turnos [ids], que tienen que caer dentro de [filter].
  /// [confirmedCount] es el total que devolvió [preview]. Es todo o nada.
  Future<SuspensionResult> suspend({
    required SuspensionFilter filter,
    required List<int> ids,
    String? observation,
    required int confirmedCount,
  });
}

/// Algún turno ya no está activo o su fecha ya pasó
/// (`TURNO_NO_SUSPENDIBLE`, 409). No se suspende ninguno.
class ShiftNotSuspendableException extends ApiException {
  const ShiftNotSuspendableException(super.message);

  String get code => 'TURNO_NO_SUSPENDIBLE';
}

/// La cantidad de consultas a cancelar cambió desde la previsualización
/// (`CONFIRMACION_DESACTUALIZADA`, 409). No se aplica nada: hay que volver a
/// previsualizar y confirmar.
class StaleSuspensionConfirmationException extends ApiException {
  const StaleSuspensionConfirmationException(super.message);

  String get code => 'CONFIRMACION_DESACTUALIZADA';
}
