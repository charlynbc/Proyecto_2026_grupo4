import '../models/access_type.dart';

/// Mensaje único de credenciales inválidas. Es fijo en el cliente: no revela
/// cuál de los dos datos falló, ni si la cuenta existe, está pendiente o
/// inactivada (RF-01, RNF-10).
const String kInvalidCredentialsMessage =
    'La cédula o la contraseña no son correctas. Revisá los datos e intentá '
    'de nuevo.';

/// Contrato de autenticación de la feature de auth.
///
/// El access token que devuelve el backend no forma parte de este contrato:
/// cada método deja el resultado en el provider de sesión (ver
/// `providers/session_provider.dart`), no lo retorna.
abstract class AuthRepository {
  /// Intenta iniciar sesión con [ci] y [password] por el acceso [access].
  ///
  /// Si las credenciales son correctas, la función retorna normalmente.
  /// Si son incorrectas, lanza [InvalidCredentialsException].
  Future<void> login({
    required String ci,
    required String password,
    required AccessType access,
  });

  /// Renueva el access token usando la cookie de refresh.
  Future<void> refresh();

  /// Cierra la sesión, tanto local como en el backend.
  Future<void> logout();
}

/// Se lanza cuando el backend rechaza la cédula y/o contraseña
/// (`CREDENCIALES_INVALIDAS`). El mensaje es siempre el mismo.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException();

  String get message => kInvalidCredentialsMessage;

  @override
  String toString() => message;
}

/// Se lanza ante cualquier otra falla: de red (sin conexión, timeout) o de
/// servidor (un código de error que no es de credenciales). Distinta de
/// [InvalidCredentialsException] para que la UI no confunda "usuario o
/// contraseña incorrectos" con "no se pudo completar la operación".
class AuthException implements Exception {
  const AuthException([
    this.message =
        'No pudimos completar la operación. Intentá de nuevo en unos minutos.',
  ]);

  final String message;

  @override
  String toString() => message;
}
