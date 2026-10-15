import 'package:dio/dio.dart';

import 'auth_repository.dart';

const String kNoConnectionMessage =
    'No pudimos conectarnos con el servidor. Revisá tu conexión a internet e '
    'intentá de nuevo.';

/// El campo `code` del error uniforme `{code, message}`, o `null`.
String? apiErrorCode(DioException e) {
  final data = e.response?.data;
  return data is Map ? data['code'] as String? : null;
}

/// Convierte una falla de red o del servidor en un [AuthException] con un
/// mensaje que se pueda mostrar tal cual. El `message` del servidor es seguro
/// para mostrar (contrato 5.1); sin respuesta (timeout, sin conexión) se usa
/// un mensaje propio.
AuthException authExceptionFrom(DioException e) {
  final data = e.response?.data;
  final message = data is Map ? data['message'] as String? : null;
  if (message != null && message.isNotEmpty) return AuthException(message);
  if (e.response == null) return const AuthException(kNoConnectionMessage);
  return const AuthException();
}
