import 'package:agenda_medica/features/auth/models/user_role.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

void main() {
  test('lee el JSON del contrato', () {
    final account = Account.fromJson(luciaJson());

    expect(account.ci, '45678911');
    expect(account.name, 'Lucía');
    expect(account.lastName, 'Fernández');
    expect(account.role, UserRole.socio);
    expect(account.email, 'lucia@example.org');
    expect(account.pendingEmail, isNull);
    expect(account.phone1, '099123456');
    expect(account.phone2, isNull);
    expect(account.address, 'Av. 18 de Julio 1234, Montevideo');
  });

  test('lee el correo pendiente y el teléfono 2 cuando vienen', () {
    final account = Account.fromJson({
      ...luciaJson(pendingEmail: 'nuevo@example.org'),
      'telefono2': '24001122',
    });

    expect(account.pendingEmail, 'nuevo@example.org');
    expect(account.phone2, '24001122');
  });

  test('lee los cuatro roles del contrato', () {
    expect(
      Account.fromJson({...luciaJson(), 'rol': 'FUNCIONARIO'}).role,
      UserRole.funcionario,
    );
    expect(
      Account.fromJson({...luciaJson(), 'rol': 'MEDICO'}).role,
      UserRole.medico,
    );
    expect(
      Account.fromJson({...luciaJson(), 'rol': 'ADMINISTRADOR'}).role,
      UserRole.administrador,
    );
  });

  test('un rol desconocido es FormatException', () {
    expect(
      () => Account.fromJson({...luciaJson(), 'rol': 'ENFERMERO'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('sin ci falla', () {
    final json = luciaJson()..remove('ci');

    expect(() => Account.fromJson(json), throwsA(isA<TypeError>()));
  });
}
