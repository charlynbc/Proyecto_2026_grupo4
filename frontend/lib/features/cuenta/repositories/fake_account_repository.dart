import '../../../core/forms/email_field_rules.dart';
import '../../auth/models/user_role.dart';
import '../models/account.dart';
import '../models/account_changes.dart';
import 'account_repository.dart';

/// Implementación en memoria de [AccountRepository] para `USE_FAKES=true`.
///
/// Parte de la persona de prueba del rol de la sesión ([personFor]).
/// Conserva los cambios en la propia instancia.
class FakeAccountRepository implements AccountRepository {
  FakeAccountRepository({
    required this._account,
    this.latency = const Duration(milliseconds: 300),
  });

  final Duration latency;
  Account _account;

  @override
  Future<Account> get() async {
    await Future<void>.delayed(latency);
    return _account;
  }

  @override
  Future<Account> update(AccountChanges changes) async {
    await Future<void>.delayed(latency);
    if (changes.isEmpty) throw const AccountValidationException.empty();

    final address = changes.address?.trim();
    final phone1 = changes.phone1?.trim();
    final phone2 = changes.phone2?.value?.trim();
    final email = changes.email?.trim();
    if (address != null && address.isEmpty) {
      throw const AccountValidationException(
        'La dirección no puede quedar vacía',
      );
    }
    if ((phone1 != null && (phone1.isEmpty || phone1.length > 30)) ||
        (phone2 != null && phone2.length > 30)) {
      throw const AccountValidationException(
        'El teléfono debe tener entre 1 y 30 caracteres',
      );
    }
    if (email != null && validateEmail(email) != null) {
      throw const AccountValidationException(
        'El correo no tiene un formato válido',
      );
    }

    final current = _account;
    final newPhone2 = phone2 == '' ? null : phone2;
    final requestsEmailChange =
        email != null && email.toLowerCase() != current.email.toLowerCase();
    return _account = Account(
      ci: current.ci,
      name: current.name,
      lastName: current.lastName,
      role: current.role,
      email: current.email,
      pendingEmail: requestsEmailChange ? email : current.pendingEmail,
      phone1: phone1 ?? current.phone1,
      phone2: changes.phone2 == null ? current.phone2 : newPhone2,
      address: address ?? current.address,
    );
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
