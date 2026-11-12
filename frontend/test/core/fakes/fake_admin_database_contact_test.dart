import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/validators/uruguayan_ci_validator.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/usuarios/models/new_user.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_status_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakeAccount _find(FakeAdminDatabase db, String ci, UserRole role) =>
    db.accounts.firstWhere((a) => a.ci == ci && a.role == role);

void main() {
  test('las cuatro cuentas de prueba traen teléfonos y dirección', () {
    final db = FakeAdminDatabase();

    final ana = _find(db, '12345672', UserRole.socio);
    expect(ana.phone1, '099111222');
    expect(ana.phone2, isNull);
    expect(ana.address, 'Bulevar Artigas 1250');

    final bruno = _find(db, '23456783', UserRole.funcionario);
    expect(bruno.phone1, '098333444');
    expect(bruno.phone2, '099555666');
    expect(bruno.address, 'Avenida Italia 2345');

    final carla = _find(db, '34567894', UserRole.medico);
    expect(carla.phone1, '094555777');
    expect(carla.phone2, isNull);
    expect(carla.address, 'Calle Mercedes 870');

    final diego = _find(db, '45678905', UserRole.administrador);
    expect(diego.phone1, '099888999');
    expect(diego.phone2, isNull);
    expect(diego.address, 'Calle Colonia 1010');
  });

  test('la cuenta anterior de Bruno comparte sus datos de contacto', () {
    final db = FakeAdminDatabase();

    final old = _find(db, '23456783', UserRole.medico);
    expect(old.phone1, '098333444');
    expect(old.address, 'Avenida Italia 2345');
  });

  test('todas las cuentas sembradas tienen teléfono 1 y dirección', () {
    final db = FakeAdminDatabase();

    for (final account in db.accounts) {
      expect(account.phone1, isNotEmpty, reason: account.ci);
      expect(account.address, isNotNull, reason: account.ci);
      expect(account.address, isNotEmpty, reason: account.ci);
    }
  });

  test(
    'cambiar el estado de una cuenta conserva sus datos de contacto',
    () async {
      final db = FakeAdminDatabase();
      final bruno = _find(db, '23456783', UserRole.funcionario);
      final repository = FakeUserStatusRepository(
        db,
        latency: Duration.zero,
        doctorsWithActiveShifts: const {},
      );

      await repository.deactivate(bruno.id);

      final after = db.accounts.firstWhere((a) => a.id == bruno.id);
      expect(after.phone1, '098333444');
      expect(after.phone2, '099555666');
      expect(after.address, 'Avenida Italia 2345');
    },
  );

  test('el alta guarda los teléfonos y la dirección del formulario', () async {
    final db = FakeAdminDatabase();
    final repository = FakeUserRepository(db, latency: Duration.zero);
    // Una cédula libre y válida: el dígito verificador es un dato de entrada.
    const body = '3644426';
    final ci = '$body${calculateUruguayanCiVerifierDigit(body)}';

    await repository.createUser(
      NewUser(
        ci: ci,
        firstName: 'Nora',
        lastName: 'Silva',
        birthDate: DateTime.utc(1991, 3, 4),
        email: 'nora@example.org',
        phone1: '091222333',
        phone2: '092444555',
        address: 'Calle Rondeau 15',
        role: UserRole.funcionario,
      ),
    );

    final created = db.accounts.last;
    expect(created.ci, ci);
    expect(created.phone1, '091222333');
    expect(created.phone2, '092444555');
    expect(created.address, 'Calle Rondeau 15');
  });
}
