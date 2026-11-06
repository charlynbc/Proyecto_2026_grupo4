/// Aviso después de confirmar el cambio de correo (contrato, fila 50).
const String kEmailChangedMessage = 'Tu correo se actualizó correctamente.';

/// Confirmación del cambio de correo con el enlace que el backend manda al
/// correo nuevo (RF-06). Pedir el cambio es otra tarjeta.
abstract class EmailChangeRepository {
  /// Aplica el cambio de correo pendiente con el [token] del enlace. Lanza
  /// [InvalidEmailChangeLinkException] si el enlace ya no sirve.
  Future<void> confirm({required String token});
}

/// `ENLACE_INVALIDO`: el enlace no existe, venció, ya se usó, fue reemplazado
/// por uno más nuevo o la cuenta fue inactivada. El servidor usa el mismo
/// código y el mismo mensaje en todos los casos, y ese mensaje se muestra tal
/// cual.
class InvalidEmailChangeLinkException implements Exception {
  const InvalidEmailChangeLinkException([
    this.message = 'El enlace ya no es válido. Pedí uno nuevo desde tu perfil.',
  ]);

  final String message;

  @override
  String toString() => message;
}
