/// Comprobar el enlace de recuperación antes de pedir la contraseña nueva
/// (contrato, fila 64). Va aparte de `PasswordRecoveryRepository` porque es
/// una consulta que no cambia nada.
abstract class PasswordRecoveryLinkRepository {
  /// Pregunta si el enlace del correo todavía sirve. Es de solo lectura: no
  /// consume el enlace y se puede repetir. Lanza `InvalidRecoveryLinkException`
  /// si el enlace ya no sirve, sin decir por qué; cualquier otra falla es una
  /// `AuthException`.
  Future<void> validateLink({required String token});
}
