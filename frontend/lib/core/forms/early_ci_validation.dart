import 'package:flutter/widgets.dart';

import '../validators/uruguayan_ci_validator.dart';
import 'early_field_validation.dart';

const String kEmptyCiMessage = 'Ingresá tu cédula.';

const String kInvalidCiMessage =
    'La cédula no es válida. Escribila completa, con el dígito verificador, '
    'sin puntos ni guiones.';

/// Validación anticipada de la cédula: hasta tener los 8 dígitos no marca
/// error. La usan los formularios que piden una cédula con el campo
/// `CiFormField` (login y alta de usuario). Ver [EarlyFieldValidation].
class EarlyCiValidation extends EarlyFieldValidation {
  EarlyCiValidation(FocusNode focusNode)
    : super(
        focusNode: focusNode,
        emptyMessage: kEmptyCiMessage,
        completeLength: 8,
        check: (ci) => isValidUruguayanCi(ci) ? null : kInvalidCiMessage,
      );
}
