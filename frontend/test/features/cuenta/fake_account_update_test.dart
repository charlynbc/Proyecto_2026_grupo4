import 'package:agenda_medica/features/cuenta/models/account_changes.dart';
import 'package:agenda_medica/features/cuenta/repositories/account_repository.dart';
import 'package:agenda_medica/features/cuenta/repositories/fake_account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

FakeAccountRepository _fake() => FakeAccountRepository(
  account: lucia(phone2: '24001122'),
  latency: Duration.zero,
);

void main() {
  test('persiste contacto y deja el correo nuevo pendiente', () async {
    final repo = _fake();
    final updated = await repo.update(
      const AccountChanges(
        address: ' Av. Italia 1234 ',
        phone1: '099000111',
        email: 'nuevo@example.org',
      ),
    );

    expect(updated.address, 'Av. Italia 1234');
    expect(updated.phone1, '099000111');
    expect(updated.phone2, '24001122');
    expect(updated.email, 'lucia@example.org');
    expect(updated.pendingEmail, 'nuevo@example.org');
    final reloaded = await repo.get();
    expect(reloaded.address, 'Av. Italia 1234');
    expect(reloaded.pendingEmail, 'nuevo@example.org');
    expect(reloaded.ci, '45678911');
  });

  test(
    'borra o cambia el segundo teléfono sin tocar los demás campos',
    () async {
      final repo = _fake();
      final cleared = await repo.update(
        const AccountChanges(phone2: (value: null)),
      );
      expect(cleared.phone2, isNull);
      expect(cleared.phone1, '099123456');
      final updated = await repo.update(
        const AccountChanges(phone2: (value: '29001122')),
      );
      expect(updated.phone2, '29001122');
    },
  );

  test('el correo actual no genera una solicitud nueva', () async {
    final repo = _fake();
    final result = await repo.update(
      const AccountChanges(email: ' LUCIA@example.org '),
    );
    expect(result.email, 'lucia@example.org');
    expect(result.pendingEmail, isNull);
  });

  final invalid = [
    (const AccountChanges(), 'No hay ningún dato para actualizar'),
    (const AccountChanges(address: ' '), 'La dirección no puede quedar vacía'),
    (
      const AccountChanges(phone1: ''),
      'El teléfono debe tener entre 1 y 30 caracteres',
    ),
    (
      AccountChanges(phone1: '1' * 31),
      'El teléfono debe tener entre 1 y 30 caracteres',
    ),
    (
      AccountChanges(phone2: (value: '1' * 31)),
      'El teléfono debe tener entre 1 y 30 caracteres',
    ),
    (
      const AccountChanges(email: 'sin-arroba'),
      'El correo no tiene un formato válido',
    ),
    (
      AccountChanges(
        address: 'Av. Italia 1234',
        email: '${'a' * 243}@example.org',
      ),
      'El correo no tiene un formato válido',
    ),
  ];

  for (final (index, (changes, message)) in invalid.indexed) {
    test('validación ${index + 1} conserva los datos anteriores', () async {
      final repo = _fake();
      await expectLater(
        repo.update(changes),
        throwsA(
          isA<AccountValidationException>().having(
            (error) => error.message,
            'message',
            message,
          ),
        ),
      );
      expect((await repo.get()).address, 'Av. 18 de Julio 1234, Montevideo');
    });
  }
}
