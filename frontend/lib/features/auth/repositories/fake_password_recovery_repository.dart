import '../models/access_type.dart';
import 'auth_repository.dart';
import 'first_login_repository.dart';
import 'password_recovery_repository.dart';

/// Implementación en memoria de [PasswordRecoveryRepository] para
/// `USE_FAKES=true`. No cambia las contraseñas de prueba: después de
/// "recuperar", se sigue ingresando con la de siempre.
///
/// El pedido siempre se acepta. Para elegir la contraseña vale cualquier
/// token, salvo [expiredToken], [usedToken] y el vacío, que simulan un enlace
/// que ya no sirve (`ENLACE_INVALIDO`).
class FakePasswordRecoveryRepository implements PasswordRecoveryRepository {
  FakePasswordRecoveryRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  static const String expiredToken = 'vencido';
  static const String usedToken = 'usado';

  final Duration latency;

  @override
  Future<void> requestLink({
    required String ci,
    required AccessType access,
  }) async {
    await Future<void>.delayed(latency);
  }

  @override
  Future<void> complete({
    required String token,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (token == expiredToken || token == usedToken || token.isEmpty) {
      throw const InvalidRecoveryLinkException();
    }
    if (password.length < kMinPasswordLength) {
      throw const AuthException(
        'La contraseña es muy corta. Usá al menos 8 caracteres.',
      );
    }
  }
}
