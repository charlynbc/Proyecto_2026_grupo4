import 'package:agenda_medica/core/forms/email_field_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta un correo válido y recorta espacios', () {
    expect(validateEmail(' a@b.co '), isNull);
  });

  test('el correo es obligatorio', () {
    expect(validateEmail('  '), 'Ingresá el correo.');
  });

  test('requiere arroba y un dominio con punto', () {
    const message = 'Ingresá un correo válido, por ejemplo nombre@ejemplo.org.';
    expect(validateEmail('sin-arroba'), message);
    expect(validateEmail('a@b'), message);
  });

  test('acepta 254 caracteres y rechaza 255', () {
    expect(validateEmail('${'a' * 242}@example.org'), isNull);
    expect(
      validateEmail('${'a' * 243}@example.org'),
      'El correo no puede tener más de 254 caracteres.',
    );
  });
}
