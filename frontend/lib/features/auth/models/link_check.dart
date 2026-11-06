/// Resultado de comprobar un enlace del correo al abrirlo. Solo distingue lo
/// que importa a la pantalla: si ya no sirve o si hay que mostrar el
/// formulario. Un fallo al comprobar (sin conexión, 401, 500, respuesta
/// rara) es [LinkCheck.valid]: no bloquea, y si el enlace era inválido el
/// aviso aparece al guardar.
class LinkCheck {
  const LinkCheck.valid() : invalidMessage = null;

  const LinkCheck.invalid(String message) : invalidMessage = message;

  /// El mensaje del enlace inválido, o `null` si hay que mostrar el
  /// formulario.
  final String? invalidMessage;

  bool get isInvalid => invalidMessage != null;
}
