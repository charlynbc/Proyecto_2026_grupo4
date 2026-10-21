import '../../../core/fakes/datos_prueba.dart';
import '../models/access_type.dart';
import '../models/user_role.dart';
import 'auth_repository.dart';
import 'first_login_repository.dart';

/// Implementación en memoria de [FirstLoginRepository] para
/// `USE_FAKES=true`.
///
/// El pedido siempre se acepta. Para activar vale cualquier token, salvo
/// [expiredToken] y [usedToken], que simulan un enlace vencido o ya usado
/// (`ENLACE_INVALIDO`). Si el token es `ci-<cédula de prueba>`, el acceso
/// resultante es el de esa persona; con cualquier otro es el de socios.
class FakeFirstLoginRepository implements FirstLoginRepository {
  FakeFirstLoginRepository({this.latency = const Duration(milliseconds: 300)});

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
  Future<AccessType> activate({
    required String token,
    required String address,
    required String phone1,
    String? phone2,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (token == expiredToken || token == usedToken || token.isEmpty) {
      throw const InvalidActivationLinkException();
    }
    if (password.length < kMinPasswordLength) {
      throw const AuthException(
        'La contraseña es muy corta. Usá al menos 8 caracteres.',
      );
    }
    if (token.startsWith('ci-')) {
      final ci = token.substring(3);
      for (final person in TestData.people) {
        final role = UserRole.tryParse(person.role);
        if (person.ci == ci && role != null) return AccessType.forRole(role);
      }
    }
    return AccessType.socio;
  }
}
