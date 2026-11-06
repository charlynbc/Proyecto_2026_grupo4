import 'package:agenda_medica/features/auth/repositories/fake_first_login_link_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_password_recovery_link_repository.dart';
import 'package:agenda_medica/features/auth/repositories/first_login_repository.dart';
import 'package:agenda_medica/features/auth/repositories/password_recovery_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakePasswordRecoveryLinkRepository _recovery() =>
    FakePasswordRecoveryLinkRepository(latency: Duration.zero);

FakeFirstLoginLinkRepository _firstLogin() =>
    FakeFirstLoginLinkRepository(latency: Duration.zero);

void main() {
  group('validar el enlace de recuperación', () {
    for (final token in ['vencido', 'usado', '']) {
      test('el token "$token" es un enlace inválido', () {
        expect(
          _recovery().validateLink(token: token),
          throwsA(isA<InvalidRecoveryLinkException>()),
        );
      });
    }

    test('el token "cualquiera" se acepta', () async {
      await _recovery().validateLink(token: 'cualquiera');
    });

    test('validar dos veces el mismo token no lo gasta', () async {
      final fake = _recovery();

      await fake.validateLink(token: 'cualquiera');
      await fake.validateLink(token: 'cualquiera');
    });
  });

  group('validar el enlace de primer ingreso', () {
    for (final token in ['vencido', 'usado', '']) {
      test('el token "$token" es un enlace inválido', () {
        expect(
          _firstLogin().validateLink(token: token),
          throwsA(isA<InvalidActivationLinkException>()),
        );
      });
    }

    test('el token "cualquiera" se acepta', () async {
      await _firstLogin().validateLink(token: 'cualquiera');
    });

    test('validar dos veces el mismo token no lo gasta', () async {
      final fake = _firstLogin();

      await fake.validateLink(token: 'cualquiera');
      await fake.validateLink(token: 'cualquiera');
    });
  });
}
