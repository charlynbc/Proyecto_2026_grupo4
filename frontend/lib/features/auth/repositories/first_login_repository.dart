import '../models/access_type.dart';
import 'auth_repository.dart';

/// Texto fijo que se muestra al pedir el enlace de primer ingreso, exista o
/// no la cuenta (RF-02, CU 3.1.2 paso 5).
const String kFirstLoginRequestedMessage =
    'Si su cédula se encuentra registrada, se le ha enviado un correo '
    'electrónico con las instrucciones.';

/// Mínimo de caracteres de la contraseña (CU 3.1.2, parámetro 3.1.3).
const int kMinPasswordLength = 8;

/// Primer ingreso: pedir el enlace por correo y activar la cuenta con él
/// (RF-02).
abstract class FirstLoginRepository {
  /// Pide el correo con el enlace. Retorna normalmente siempre que el pedido
  /// llegue al servidor, exista o no la cuenta; no revela nada más.
  Future<void> requestLink({required String ci, required AccessType access});

  /// Completa la activación con el [token] del enlace. Devuelve el acceso por
  /// el que la persona debe ingresar ahora. Lanza
  /// [InvalidActivationLinkException] si el enlace venció, ya se usó o la
  /// cuenta no se puede activar.
  Future<AccessType> activate({
    required String token,
    required String address,
    required String phone1,
    String? phone2,
    required String password,
  });
}

/// `ENLACE_INVALIDO`: el enlace no existe, venció, ya se usó o la cuenta fue
/// inactivada. El servidor usa el mismo código para los cuatro casos.
class InvalidActivationLinkException implements Exception {
  const InvalidActivationLinkException([this._message]);

  final String? _message;

  String get message =>
      _message ??
      'El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.';

  @override
  String toString() => message;
}

/// Mensaje para mostrar de una falla de [AuthException]; cualquier otra cosa
/// cae en el mensaje genérico.
String authMessageOf(Object error) =>
    error is AuthException ? error.message : const AuthException().message;
