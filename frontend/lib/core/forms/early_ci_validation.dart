import 'package:flutter/widgets.dart';

import '../validators/uruguayan_ci_validator.dart';

const String kEmptyCiMessage = 'Ingresá tu cédula.';

const String kInvalidCiMessage =
    'La cédula no es válida. Escribila completa, con el dígito verificador, '
    'sin puntos ni guiones.';

/// Validación de la cédula "sin molestar": mientras se escribe no marca error
/// hasta tener los 8 dígitos, y un campo vacío no es una cédula mal escrita,
/// así que solo se reclama al enviar. La usan los formularios que piden una
/// cédula con el campo `CiFormField` (login y alta de usuario).
///
/// El formulario tiene que hacer `setState` cuando cambia el foco de
/// [focusNode]: el campo solo revalida cuando el formulario se reconstruye,
/// y sin eso no se revalida al perder el foco.
class EarlyCiValidation {
  EarlyCiValidation(this.focusNode);

  /// El foco del campo de la cédula.
  final FocusNode focusNode;

  bool _validatingAll = false;
  bool _submitAttempted = false;

  /// Verdadero solo mientras corre [validateAll]: ahí se ignora el foco.
  bool get validatingAll => _validatingAll;

  /// El usuario está escribiendo en [node] y no se está validando el envío.
  bool isTyping(FocusNode node) => node.hasFocus && !_validatingAll;

  /// Validador del campo de la cédula.
  String? validate(String? value) {
    final ci = value?.trim() ?? '';
    // Un campo en blanco solo se reclama al enviar, y después del primer
    // intento mientras no se esté escribiendo. El intento persiste porque, sin
    // él, el error de un campo vacío que el usuario ya tocó se borra en el
    // próximo rebuild, que lo revalida cuando [_validatingAll] ya volvió a
    // falso.
    if (ci.isEmpty) {
      final claim = _validatingAll || (_submitAttempted && !focusNode.hasFocus);
      return claim ? kEmptyCiMessage : null;
    }
    if (isTyping(focusNode) && ci.length < 8) return null;
    return isValidUruguayanCi(ci) ? null : kInvalidCiMessage;
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
