import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/widgets/user_actions_menu.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

UserAccount _row(int id, String ci, UserRole role) => UserAccount(
  id: id,
  ci: ci,
  firstName: 'Fila',
  lastName: 'De prueba',
  role: role,
  email: 'fila@example.org',
  status: AccountStatus.active,
  activated: true,
  createdAt: DateTime.utc(2026, 1, 1),
);

AsyncValue<Account> _session(int id, String ci) => AsyncData(
  Account(
    id: id,
    ci: ci,
    name: 'Sesión',
    lastName: 'De prueba',
    role: UserRole.administrador,
    email: 'sesion@example.org',
    pendingEmail: null,
    phone1: '099000000',
    phone2: null,
    address: 'Calle 1',
  ),
);

void main() {
  test('la fila con el id de la sesión no se gestiona', () {
    final row = _row(5, '45678905', UserRole.administrador);

    expect(canManageAccount(row, _session(5, '45678905')), isFalse);
  });

  test('la fila propia no se gestiona aunque su CI sea otra', () {
    final row = _row(5, '45678906', UserRole.administrador);

    expect(canManageAccount(row, _session(5, '45678905')), isFalse);
  });

  test('otro administrador con la misma CI y distinto id se gestiona', () {
    final row = _row(9, '45678905', UserRole.administrador);

    expect(canManageAccount(row, _session(5, '45678905')), isTrue);
  });

  test('otra cuenta de empleado con distinto id se gestiona', () {
    final row = _row(2, '23456783', UserRole.funcionario);

    expect(canManageAccount(row, _session(5, '45678905')), isTrue);
  });

  test('un socio nunca se gestiona', () {
    final row = _row(1, '12345672', UserRole.socio);

    expect(canManageAccount(row, _session(5, '45678905')), isFalse);
  });

  test('mientras la cuenta carga no se gestiona un administrador', () {
    final row = _row(9, '78901238', UserRole.administrador);

    expect(canManageAccount(row, const AsyncLoading()), isFalse);
  });

  test('si la cuenta falla no se gestiona un administrador', () {
    final row = _row(9, '78901238', UserRole.administrador);

    expect(
      canManageAccount(row, AsyncError(const ApiException(), StackTrace.empty)),
      isFalse,
    );
  });

  test(
    'mientras la cuenta carga se gestiona a un empleado no administrador',
    () {
      final row = _row(2, '23456783', UserRole.funcionario);

      expect(canManageAccount(row, const AsyncLoading()), isTrue);
    },
  );

  test('mientras la cuenta carga un socio tampoco se gestiona', () {
    final row = _row(1, '12345672', UserRole.socio);

    expect(canManageAccount(row, const AsyncLoading()), isFalse);
  });
}
