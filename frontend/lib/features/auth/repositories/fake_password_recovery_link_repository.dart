import 'fake_password_recovery_repository.dart';
import 'password_recovery_link_repository.dart';
import 'password_recovery_repository.dart';

/// Implementación en memoria de [PasswordRecoveryLinkRepository] para
/// `USE_FAKES=true`. Rechaza los mismos tokens que
/// [FakePasswordRecoveryRepository.complete]: `vencido`, `usado` y el vacío.
/// Cualquier otro sirve, y se puede consultar las veces que haga falta.
class FakePasswordRecoveryLinkRepository
    implements PasswordRecoveryLinkRepository {
  FakePasswordRecoveryLinkRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  @override
  Future<void> validateLink({required String token}) async {
    await Future<void>.delayed(latency);
    if (token == FakePasswordRecoveryRepository.expiredToken ||
        token == FakePasswordRecoveryRepository.usedToken ||
        token.isEmpty) {
      throw const InvalidRecoveryLinkException();
    }
  }
}
