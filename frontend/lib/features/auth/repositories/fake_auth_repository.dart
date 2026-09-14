import 'auth_repository.dart';

/// Implementación fake de [AuthRepository] mientras no exista contrato de
/// backend. Acepta una única credencial hardcodeada y rechaza cualquier
/// otra combinación.
///
/// TODO: reemplazar por una implementación real que use dioProvider en
/// cuanto el backend defina el endpoint de login. La UI no debería requerir
/// cambios: solo hay que cambiar qué implementación de AuthRepository
/// provee authRepositoryProvider.
class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository();

  static const _validCi = '12345672';
  static const _validPassword = 'socio123';

  @override
  Future<void> login({required String ci, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (ci != _validCi || password != _validPassword) {
      throw const InvalidCredentialsException();
    }
  }
}
