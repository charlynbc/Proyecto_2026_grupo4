import '../../../core/network/api_exception.dart';
import '../models/account_status_change.dart';

/// Inactivar y reactivar cuentas de empleado (contrato, filas 61 y 62,
/// RF-45). Es un repositorio aparte para no tocar [UserRepository] ni sus
/// dobles.
abstract class UserStatusRepository {
  /// Inactiva la cuenta [id]: no puede ingresar y se cierran sus sesiones.
  Future<AccountStatusChange> deactivate(int id);

  /// Reactiva la cuenta [id].
  Future<AccountStatusChange> reactivate(int id);
}

/// Por qué no se pudo cambiar el estado de la cuenta.
enum UserStatusFailure {
  notFound,
  alreadyInactive,
  alreadyActive,
  doctorHasShifts,
  doctorHasAppointments,
  duplicateStaff,
  validation,
  other,
}

/// Un cambio de estado rechazado. El [message] es el del servidor.
class UserStatusException extends ApiException {
  const UserStatusException(this.failure, [super.message]);

  final UserStatusFailure failure;
}
