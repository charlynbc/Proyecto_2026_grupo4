import 'package:dio/dio.dart';

const String kApiGenericMessage =
    'Ocurrió un problema de nuestro lado. Intentá de nuevo en unos minutos.';

const String kApiNoConnectionMessage =
    'No pudimos conectarnos con el servidor. Revisá tu conexión a internet e '
    'intentá de nuevo.';

/// El campo `code` del error uniforme `{code, message}`, o `null`.
String? apiCodeOf(DioException e) {
  final data = e.response?.data;
  return data is Map ? data['code'] as String? : null;
}

/// Falla de la API con un [message] que se puede mostrar tal cual (el
/// `message` del servidor es seguro para mostrar, contrato 5.1). Los casos
/// que la pantalla distingue son subclases, que el repository elige por
/// `code` y nunca por el texto.
class ApiException implements Exception {
  const ApiException([this.message = kApiGenericMessage]);

  /// Convierte una falla de dio: usa el `message` del servidor y, sin
  /// respuesta (timeout, sin conexión), un mensaje propio.
  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    final message = data is Map ? data['message'] as String? : null;
    if (message != null && message.isNotEmpty) return ApiException(message);
    if (e.response == null) return const ApiException(kApiNoConnectionMessage);
    return const ApiException();
  }

  final String message;

  @override
  String toString() => message;
}

/// Mensaje para mostrar de cualquier error; lo que no es una [ApiException]
/// cae en el mensaje genérico.
String apiMessageOf(Object error) =>
    error is ApiException ? error.message : kApiGenericMessage;
