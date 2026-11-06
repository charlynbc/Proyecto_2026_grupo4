import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/repositories/fake_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> expectPerson(
    UserRole role, {
    required String ci,
    required String name,
    required String lastName,
    required String email,
    required String phone1,
    required String? phone2,
    required String address,
  }) async {
    final repo = FakeAccountRepository(
      account: FakeAccountRepository.personFor(role),
      latency: Duration.zero,
    );

    final account = await repo.get();

    expect(account.role, role);
    expect(account.ci, ci);
    expect(account.name, name);
    expect(account.lastName, lastName);
    expect(account.email, email);
    expect(account.pendingEmail, isNull);
    expect(account.phone1, phone1);
    expect(account.phone2, phone2);
    expect(account.address, address);
  }

  test('el socio es Ana Rodríguez', () async {
    await expectPerson(
      UserRole.socio,
      ci: '12345672',
      name: 'Ana',
      lastName: 'Rodríguez',
      email: 'ana.rodriguez@example.org',
      phone1: '099123456',
      phone2: null,
      address: 'Av. 18 de Julio 1234, Montevideo',
    );
  });

  test('el funcionario es Bruno Pereira', () async {
    await expectPerson(
      UserRole.funcionario,
      ci: '23456783',
      name: 'Bruno',
      lastName: 'Pereira',
      email: 'bruno.pereira@example.org',
      phone1: '099234567',
      phone2: '24001122',
      address: 'Bulevar Artigas 500, Montevideo',
    );
  });

  test('el médico es Carla Méndez', () async {
    await expectPerson(
      UserRole.medico,
      ci: '34567894',
      name: 'Carla',
      lastName: 'Méndez',
      email: 'carla.mendez@example.org',
      phone1: '099345678',
      phone2: null,
      address: 'Av. Italia 2500, Montevideo',
    );
  });

  test('el administrador es Diego Fernández', () async {
    await expectPerson(
      UserRole.administrador,
      ci: '45678905',
      name: 'Diego',
      lastName: 'Fernández',
      email: 'diego.fernandez@example.org',
      phone1: '099456789',
      phone2: null,
      address: '8 de Octubre 3000, Montevideo',
    );
  });
}
