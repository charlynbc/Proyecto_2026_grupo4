final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return 'Ingresá el correo.';
  if (email.length > 254) {
    return 'El correo no puede tener más de 254 caracteres.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Ingresá un correo válido, por ejemplo nombre@ejemplo.org.';
  }
  return null;
}
