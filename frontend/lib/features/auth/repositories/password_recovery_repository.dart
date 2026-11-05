import '../models/access_type.dart';

/// Texto fijo que se muestra al pedir el enlace de recuperación, exista o no
/// la cuenta (RF-05, RNF-10: no confirma si la cuenta existe).
const String kPasswordRecoveryRequestedMessage =
    'Si su cédula se encuentra registrada, se le ha enviado un correo '
    'electrónico con las instrucciones.';

/// Aviso del login después de elegir la contraseña nueva (`recuperada=1`).
const String kPasswordRecoveredMessage =
    'Tu contraseña se actualizó correctamente. Ya podés iniciar sesión.';

/// Máximo de la contraseña en bytes UTF-8 (contrato, fila 49): una letra con
/// tilde o una ñ ocupa dos.
const int kMaxPasswordBytes = 72;

/// Recuperación de la contraseña: pedir el enlace por correo y elegir la
/// contraseña nueva con él (RF-05).
abstract class PasswordRecoveryRepository {
  /// Pide el correo con el enlace. Retorna normalmente siempre que el pedido
  /// llegue al servidor, exista o no la cuenta; no revela nada más.
  Future<void> requestLink({required String ci, required AccessType access});

  /// Guarda la contraseña nueva con el [token] del enlace. No inicia sesión.
  /// Lanza [InvalidRecoveryLinkException] si el enlace ya no sirve.
  Future<void> complete({required String token, required String password});
}

/// `ENLACE_INVALIDO`: el enlace no existe, venció, ya se usó, fue reemplazado
/// por uno más nuevo o la cuenta fue inactivada. El servidor usa el mismo
/// código y el mismo mensaje en todos los casos, y ese mensaje se muestra tal
/// cual.
class InvalidRecoveryLinkException implements Exception {
  const InvalidRecoveryLinkException([
    this.message =
        'El enlace ya no es válido. Pedí uno nuevo desde la pantalla de '
        'ingreso.',
  ]);

  final String message;

  @override
  String toString() => message;
}
