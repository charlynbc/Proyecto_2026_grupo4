/// Contrato de autenticación de la feature de auth.
///
/// El access token que devuelve el backend no forma parte de este contrato:
/// cada método deja el resultado en el provider de sesión (ver
/// `providers/session_provider.dart`), no lo retorna.
abstract class AuthRepository {
  /// Intenta iniciar sesión con [ci] y [password].
  ///
  /// Si las credenciales son correctas, la función retorna normalmente.
  /// Si son incorrectas, lanza [InvalidCredentialsException].
  Future<void> login({required String ci, required String password});

  /// Renueva el access token usando la cookie de refresh.
  Future<void> refresh();

  /// Cierra la sesión, tanto local como en el backend.
  Future<void> logout();
}

/// Se lanza cuando el backend rechaza la cédula y/o contraseña
/// (`CREDENCIALES_INVALIDAS`).
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException([
    this.message = 'Los datos ingresados no son correctos.',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Se lanza ante cualquier otra falla: de red (sin conexión, timeout) o de
/// servidor (un código de error que no es de credenciales). Distinta de
/// [InvalidCredentialsException] para que la UI no confunda "usuario o
/// contraseña incorrectos" con "no se pudo completar la operación".
class AuthException implements Exception {
  const AuthException([
    this.message = 'No pudimos completar la operación. Intentá de nuevo.',
  ]);

  final String message;

  @override
  String toString() => message;
}
