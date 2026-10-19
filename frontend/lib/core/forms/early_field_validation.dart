import 'package:flutter/widgets.dart';

/// Validación de un campo "sin molestar": mientras se escribe no marca error
/// hasta que el texto tiene [completeLength] caracteres, y un campo vacío no es
/// un dato mal escrito, así que solo se reclama al enviar. La usan la cédula y
/// la fecha de nacimiento.
///
/// El formulario tiene que hacer `setState` cuando cambia el foco de
/// [focusNode]: el campo solo revalida cuando el formulario se reconstruye,
/// y sin eso no se revalida al perder el foco.
class EarlyFieldValidation {
  EarlyFieldValidation({
    required this.focusNode,
    required this.emptyMessage,
    required this.completeLength,
    required this.check,
  });

  /// El foco del campo.
  final FocusNode focusNode;

  /// Lo que se reclama si el campo está en blanco al enviar.
  final String emptyMessage;

  /// Con foco y menos caracteres que estos, todavía no se marca error.
  final int completeLength;

  /// El error de un texto no vacío, o `null` si está bien.
  final String? Function(String text) check;

  bool _validatingAll = false;
  bool _submitAttempted = false;

  /// Verdadero solo mientras corre [validateAll]: ahí se ignora el foco.
  bool get validatingAll => _validatingAll;

  /// El usuario está escribiendo en [node] y no se está validando el envío.
  bool isTyping(FocusNode node) => node.hasFocus && !_validatingAll;

  /// Validador del campo.
  String? validate(String? value) {
    final text = value?.trim() ?? '';
    // Un campo en blanco solo se reclama al enviar, y después del primer
    // intento mientras no se esté escribiendo. El intento persiste porque, sin
    // él, el error de un campo vacío que el usuario ya tocó se borra en el
    // próximo rebuild, que lo revalida cuando [_validatingAll] ya volvió a
    // falso.
    if (text.isEmpty) {
      final claim = _validatingAll || (_submitAttempted && !focusNode.hasFocus);
      return claim ? emptyMessage : null;
    }
    if (isTyping(focusNode) && text.length < completeLength) return null;
    return check(text);
  }

  /// Valida todo el formulario al enviarlo, con [validateForm], ignorando el
  /// foco. Devuelve si el formulario es válido.
  bool validateAll(bool Function() validateForm) {
    _submitAttempted = true;
    _validatingAll = true;
    try {
      return validateForm();
    } finally {
      _validatingAll = false;
    }
  }
}
