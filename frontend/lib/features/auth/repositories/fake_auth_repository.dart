import '../../../core/fakes/datos_prueba.dart';
import '../providers/session_provider.dart';
import 'auth_repository.dart';

/// Implementación en memoria de [AuthRepository] para `USE_FAKES=true`.
///
/// Acepta cualquier cédula de `TestData.people` con la contraseña
/// [kTestPassword] y deja en sesión el rol de esa persona. Cualquier otra
/// combinación falla como un 401 (`CREDENCIALES_INVALIDAS`).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(
    this._session, {
    this.latency = const Duration(milliseconds: 300),
  });

  final SessionNotifier _session;
  final Duration latency;

  @override
  Future<void> login({required String ci, required String password}) async {
    await Future<void>.delayed(latency);
    final matches = TestData.people.where((p) => p.ci == ci);
    if (matches.isEmpty || password != kTestPassword) {
      throw const InvalidCredentialsException();
    }
    _session.setAuthenticated(
      accessToken: 'token-de-prueba-$ci',
      role: matches.first.role,
    );
  }

  /// No hay cookie de refresh en memoria: al arrancar la app no hay sesión
  /// previa, igual que contra la API real sin cookie (401).
  @override
  Future<void> refresh() async {
    await Future<void>.delayed(latency);
    throw const AuthException();
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(latency);
    _session.clear();
  }
}
