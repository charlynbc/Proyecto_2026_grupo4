import '../models/staff_cancellation_result.dart';

/// Largo máximo del motivo de una cancelación por otro motivo (RF-19).
const int kStaffCancellationReasonMaxLength = 1000;

abstract class StaffCancellationRepository {
  /// Cancela la consulta [id]. Sin [reason] es a pedido del socio y no lleva
  /// motivo; con [reason] es por otro motivo (administrativo u otro) y el
  /// motivo es obligatorio.
  Future<StaffCancellationResult> cancel(int id, {String? reason});
}

/// El motivo recortado, o una [StaffCancellationException] de validación si
/// está vacío o pasa de [kStaffCancellationReasonMaxLength]. El servidor
/// vuelve a validarlo: acá solo se ayuda al usuario.
String validatedStaffCancellationReason(String reason) {
  final trimmed = reason.trim();
  if (trimmed.isEmpty) {
    throw const StaffCancellationException(
      StaffCancellationFailure.validation,
      'Escribí el motivo de la cancelación.',
    );
  }
  if (trimmed.length > kStaffCancellationReasonMaxLength) {
    throw const StaffCancellationException(
      StaffCancellationFailure.validation,
      'El motivo no puede tener más de $kStaffCancellationReasonMaxLength '
      'caracteres.',
    );
  }
  return trimmed;
}

enum StaffCancellationFailure {
  notFound,
  notScheduled,
  outsideWindow,
  conflictOfInterest,
  validation,
  unauthenticated,
  forbidden,
  other,
}

class StaffCancellationException implements Exception {
  const StaffCancellationException(this.failure, this.message);

  final StaffCancellationFailure failure;
  final String message;

  @override
  String toString() => message;
}
