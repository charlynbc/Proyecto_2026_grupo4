import '../../../core/network/api_exception.dart';
import '../models/new_user.dart';
import '../models/user_filters.dart';
import '../models/user_page.dart';

/// Administración de usuarios (contrato #11 y #12, RF-31 y RF-35).
abstract class UserRepository {
  /// Da de alta una cuenta pendiente de primer ingreso. No envía correo.
  /// Lanza [InvalidCiException], [MismatchedPersonDataException],
  /// [DuplicateMemberException] o [DuplicateStaffException] según el motivo
  /// del rechazo; cualquier otra falla es una [ApiException].
  Future<void> createUser(NewUser user);

  /// Una página del padrón, una fila por cuenta.
  Future<UserPage> listUsers(UserFilters filters);
}

/// `CI_INVALIDA`: el dígito verificador no corresponde.
class InvalidCiException extends ApiException {
  const InvalidCiException([
    super.message =
        'La cédula no es válida. Revisá los números, incluido el último.',
  ]);
}

/// `DATOS_PERSONA_DISCORDANTES`: la cédula ya existe con otro nombre,
/// apellido o fecha de nacimiento.
class MismatchedPersonDataException extends ApiException {
  const MismatchedPersonDataException([
    super.message =
        'Esa cédula ya está registrada con otro nombre, apellido o fecha de '
        'nacimiento. Corregí primero esos datos del padrón y volvé a '
        'intentar.',
  ]);
}

/// `SOCIO_DUPLICADO`: la cédula ya tiene una cuenta de socio.
class DuplicateMemberException extends ApiException {
  const DuplicateMemberException([
    super.message = 'Esa cédula ya tiene una cuenta de socio.',
  ]);
}

/// `EMPLEADO_DUPLICADO`: la cédula ya tiene una cuenta de empleado
/// habilitada o pendiente de activar.
class DuplicateStaffException extends ApiException {
  const DuplicateStaffException([
    super.message =
        'Esa cédula ya tiene una cuenta de empleado habilitada o pendiente de '
        'activar. Para darle otro rol, inactivá primero la cuenta anterior.',
  ]);
}
