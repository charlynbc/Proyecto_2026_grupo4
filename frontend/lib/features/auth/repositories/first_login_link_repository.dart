/// Comprobar el enlace de primer ingreso antes de pedir los datos (contrato,
/// fila 63). Va aparte de `FirstLoginRepository` porque es una consulta que
/// no cambia nada.
abstract class FirstLoginLinkRepository {
  /// Pregunta si el enlace del correo todavía sirve. Es de solo lectura: no
  /// consume el enlace y se puede repetir. Lanza
  /// `InvalidActivationLinkException` si el enlace ya no sirve, sin decir por
  /// qué; cualquier otra falla es una `AuthException`.
  Future<void> validateLink({required String token});
}
