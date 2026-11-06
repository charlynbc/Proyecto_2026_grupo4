import 'package:agenda_medica/features/auth/repositories/email_change_repository.dart';
import 'package:agenda_medica/features/auth/repositories/fake_email_change_repository.dart';
import 'package:flutter_test/flutter_test.dart';

FakeEmailChangeRepository _fake() =>
    FakeEmailChangeRepository(latency: Duration.zero);

void main() {
  for (final token in ['vencido', 'usado', '']) {
    test('el token "$token" es un enlace inválido', () {
      expect(
        _fake().confirm(token: token),
        throwsA(isA<InvalidEmailChangeLinkException>()),
      );
    });
  }

  test('un token cualquiera termina bien', () async {
    await _fake().confirm(token: 'cualquiera');
  });
}
