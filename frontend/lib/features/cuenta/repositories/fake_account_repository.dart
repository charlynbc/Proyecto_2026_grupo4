import '../../auth/models/user_role.dart';
import '../models/account.dart';
import 'account_repository.dart';

/// Implementación en memoria de [AccountRepository] para `USE_FAKES=true`.
///
/// Devuelve [account], la persona de prueba del rol de la sesión
/// ([personFor]). Guarda la cuenta en la propia instancia, que el provider
/// conserva, para que la tarjeta de edición pueda modificarla.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    required this.account,
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;

  /// La cuenta que devuelve `get`.
  final Account account;

  @override
  Future<Account> get() async {
    await Future<void>.delayed(latency);
    return account;
  }

  /// La persona de prueba de cada rol, escrita acá a mano (las mismas CI que
  /// `TestData.people`). Ninguna tiene un correo pendiente.
  static Account personFor(UserRole role) => switch (role) {
    UserRole.socio => const Account(
      ci: '12345672',
      name: 'Ana',
      lastName: 'Rodríguez',
      role: UserRole.socio,
      email: 'ana.rodriguez@example.org',
      pendingEmail: null,
      phone1: '099123456',
      phone2: null,
      address: 'Av. 18 de Julio 1234, Montevideo',
    ),
    UserRole.funcionario => const Account(
      ci: '23456783',
      name: 'Bruno',
      lastName: 'Pereira',
      role: UserRole.funcionario,
      email: 'bruno.pereira@example.org',
      pendingEmail: null,
      phone1: '099234567',
      phone2: '24001122',
      address: 'Bulevar Artigas 500, Montevideo',
    ),
    UserRole.medico => const Account(
      ci: '34567894',
      name: 'Carla',
      lastName: 'Méndez',
      role: UserRole.medico,
      email: 'carla.mendez@example.org',
      pendingEmail: null,
      phone1: '099345678',
      phone2: null,
      address: 'Av. Italia 2500, Montevideo',
    ),
    UserRole.administrador => const Account(
      ci: '45678905',
      name: 'Diego',
      lastName: 'Fernández',
      role: UserRole.administrador,
      email: 'diego.fernandez@example.org',
      pendingEmail: null,
      phone1: '099456789',
      phone2: null,
      address: '8 de Octubre 3000, Montevideo',
    ),
  };
}
