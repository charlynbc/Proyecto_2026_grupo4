/// Contrato de autenticación de la feature de auth.
///
/// El token de sesión viaja en cookies HttpOnly que dio maneja solo (ver
/// core/network/dio_client.dart); por eso el contrato no modela tokens,
/// solo éxito o fracaso del intento de login.
abstract class AuthRepository {
  /// Intenta iniciar sesión con [ci] y [password].
  ///
  /// Si las credenciales son correctas, la función retorna normalmente.
  /// Si son incorrectas, lanza [InvalidCredentialsException].
  Future<void> login({required String ci, required String password});
}

/// Se lanza cuando el backend (o su fake) rechaza la cédula y/o contraseña.
class InvalidCredentialsException implements Exception {
  const InvalidCredentialsException([
    this.message = 'Los datos ingresados no son correctos.',
  ]);

  final String message;

  @override
  String toString() => message;
}
