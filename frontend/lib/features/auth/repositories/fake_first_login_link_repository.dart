import 'fake_first_login_repository.dart';
import 'first_login_link_repository.dart';
import 'first_login_repository.dart';

/// Implementación en memoria de [FirstLoginLinkRepository] para
/// `USE_FAKES=true`. Rechaza los mismos tokens que
/// [FakeFirstLoginRepository.activate]: `vencido`, `usado` y el vacío.
/// Cualquier otro sirve, y se puede consultar las veces que haga falta.
class FakeFirstLoginLinkRepository implements FirstLoginLinkRepository {
  FakeFirstLoginLinkRepository({
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  @override
  Future<void> validateLink({required String token}) async {
    await Future<void>.delayed(latency);
    if (token == FakeFirstLoginRepository.expiredToken ||
        token == FakeFirstLoginRepository.usedToken ||
        token.isEmpty) {
      throw const InvalidActivationLinkException();
    }
  }
}
