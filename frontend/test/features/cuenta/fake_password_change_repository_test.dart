import 'package:agenda_medica/features/cuenta/repositories/fake_password_change_repository.dart';
import 'package:agenda_medica/features/cuenta/repositories/password_change_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'guarda la nueva clave y exige la vigente en el siguiente cambio',
    () async {
      final repository = FakePasswordChangeRepository(latency: Duration.zero);
      await repository.change(
        currentPassword: 'prueba1234',
        newPassword: 'claveNueva9',
      );
      await expectLater(
        repository.change(
          currentPassword: 'prueba1234',
          newPassword: 'otraClave9',
        ),
        throwsA(
          isA<PasswordChangeException>().having(
            (e) => e.failure,
            'failure',
            PasswordChangeFailure.wrongCurrentPassword,
          ),
        ),
      );
      await repository.change(
        currentPassword: 'claveNueva9',
        newPassword: 'otraClave9',
      );
    },
  );

  test('rechaza una clave nueva de siete caracteres', () async {
    final repository = FakePasswordChangeRepository(latency: Duration.zero);
    await expectLater(
      repository.change(currentPassword: 'prueba1234', newPassword: '1234567'),
      throwsA(
        isA<PasswordChangeException>().having(
          (e) => e.failure,
          'failure',
          PasswordChangeFailure.validation,
        ),
      ),
    );
  });
}
