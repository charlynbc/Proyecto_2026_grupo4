import '../../../core/network/api_exception.dart';
import '../models/device_registration.dart';

/// Registro y baja del token push del dispositivo del socio (RNF-23,
/// contrato filas 33 y 73). Solo Android.
abstract class DeviceRepository {
  /// `POST /api/dispositivos`. Idempotente: registrar dos veces el mismo
  /// token no crea otra fila.
  Future<DeviceRegistration> register(String token);

  /// `POST /api/dispositivos/baja`. El servidor responde 204 aunque el token
  /// no exista o sea de otro socio.
  Future<void> deactivate(String token);
}

enum DeviceFailure {
  /// `VALIDACION` (400): el token falta, está vacío o es demasiado largo.
  validation,

  /// `NO_AUTENTICADO` (401): la sesión no es válida.
  unauthenticated,

  /// `ACCESO_DENEGADO` (403): la cuenta no es de un socio.
  forbidden,

  /// Sin respuesta del servidor o un `code` que no se conoce.
  other,
}

class DeviceException extends ApiException {
  const DeviceException(this.failure, [super.message]);

  final DeviceFailure failure;
}
