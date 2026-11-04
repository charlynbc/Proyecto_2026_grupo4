import 'package:agenda_medica/features/auth/models/access_type.dart';
import 'package:agenda_medica/features/auth/repositories/auth_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_password_recovery_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakePasswordRecoveryRepository _fake() =>
    FakePasswordRecoveryRepository(latency: Duration.zero);

void main() {
  test('pedir el enlace siempre termina bien', () async {
    await _fake().requestLink(ci: '12345672', access: AccessType.socio);
    await _fake().requestLink(ci: '23456783', access: AccessType.empleado);
  });

  for (final token in ['vencido', 'usado', '']) {
    test('el token "$token" es un enlace inválido', () {
      expect(
        _fake().complete(token: token, password: 'claveNueva9'),
        throwsA(isA<InvalidRecoveryLinkException>()),
      );
    });
  }

  test('una contraseña de 7 caracteres da AuthException', () {
    expect(
      _fake().complete(token: 'cualquiera', password: 'corta12'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          'La contraseña es muy corta. Usá al menos 8 caracteres.',
        ),
      ),
    );
  });

  test('un token cualquiera con claveNueva9 termina bien', () async {
    await _fake().complete(token: 'cualquiera', password: 'claveNueva9');
  });
}
