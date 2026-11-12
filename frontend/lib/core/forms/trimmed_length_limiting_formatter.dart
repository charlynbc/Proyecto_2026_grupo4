import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Limita lo que se puede escribir o pegar en un campo de texto para que el
/// texto recortado con `trim()` tenga como máximo [maxLength] unidades UTF-16.
///
/// Es la misma cuenta que hacen las validaciones y el servidor (`trim().length`),
/// a diferencia de `maxLength` del campo, que cuenta caracteres visibles y
/// cuenta los espacios de los bordes:
///
/// - Si el texto nuevo ya cumple, se acepta tal cual.
/// - Si no, se corta al final, conservando los espacios de la izquierda (no
///   cuentan) y descartando los espacios finales que queden al cortar.
/// - Nunca se parte un par sustituto: si el corte cae entre las dos mitades de
///   un emoji, se saca el emoji entero.
/// - La selección del resultado queda colapsada al final del texto cortado.
class TrimmedLengthLimitingFormatter extends TextInputFormatter {
  const TrimmedLengthLimitingFormatter(this.maxLength)
    : assert(maxLength > 0, 'El máximo tiene que ser positivo');

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.trim().length <= maxLength) return newValue;

    // Los espacios de la izquierda se conservan y no cuentan: el contenido
    // empieza después de ellos y de él entran [maxLength] unidades.
    final leading = text.length - text.trimLeft().length;
    var end = math.min(leading + maxLength, text.length);
    if (end > 0 &&
        end < text.length &&
        _isHighSurrogate(text.codeUnitAt(end - 1))) {
      end--;
    }
    final cut = text.substring(0, end).trimRight();
    return TextEditingValue(
      text: cut,
      selection: TextSelection.collapsed(offset: cut.length),
    );
  }

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
}
