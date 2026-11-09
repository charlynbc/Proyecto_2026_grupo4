import 'package:agenda_medica/features/cuenta/models/account_changes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('incluye solo la dirección cambiada y recortada', () {
    const changes = AccountChanges(address: '  Av. Italia 1234  ');
    expect(changes.toJson(), {'direccion': 'Av. Italia 1234'});
    expect(changes.isEmpty, isFalse);
  });

  test('serializa dirección, teléfono principal y correo', () {
    const changes = AccountChanges(
      address: 'Av. Italia 1234',
      phone1: ' 099000111 ',
      email: ' nuevo@example.org ',
    );
    expect(changes.toJson(), {
      'direccion': 'Av. Italia 1234',
      'telefono1': '099000111',
      'correo': 'nuevo@example.org',
    });
  });

  test('el segundo teléfono puede cambiar o borrarse con null explícito', () {
    expect(const AccountChanges(phone2: (value: ' 24001122 ')).toJson(), {
      'telefono2': '24001122',
    });
    const removal = AccountChanges(phone2: (value: null));
    expect(removal.toJson(), {'telefono2': null});
    expect(removal.isEmpty, isFalse);
  });

  test('sin cambios no hay campos para enviar', () {
    const changes = AccountChanges();
    expect(changes.toJson(), isEmpty);
    expect(changes.isEmpty, isTrue);
  });
}
