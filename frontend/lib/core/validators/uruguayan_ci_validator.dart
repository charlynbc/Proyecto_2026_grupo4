/// Coeficientes del algoritmo de dígito verificador de la cédula uruguaya,
/// aplicados a los primeros siete dígitos del cuerpo del número.
const List<int> _kCoefficients = [2, 9, 8, 7, 6, 3, 4];

final RegExp _kBodyPattern = RegExp(r'^\d{6,7}$');
final RegExp _kFullCiPattern = RegExp(r'^\d{7,8}$');

/// Calcula el dígito verificador para el cuerpo de una cédula uruguaya
/// ([digits], sin el propio verificador). Acepta cuerpos de 6 o 7 dígitos:
/// los de 6 se completan con un cero a la izquierda antes de aplicar los
/// coeficientes, tal como exige el algoritmo oficial.
int calculateUruguayanCiVerifierDigit(String digits) {
  if (!_kBodyPattern.hasMatch(digits)) {
    throw ArgumentError.value(
      digits,
      'digits',
      'Debe tener 6 o 7 dígitos numéricos',
    );
  }

  final padded = digits.padLeft(7, '0');
  var sum = 0;
  for (var i = 0; i < 7; i++) {
    sum += int.parse(padded[i]) * _kCoefficients[i];
  }
  return (10 - (sum % 10)) % 10;
}

/// Valida una cédula uruguaya completa (cuerpo + dígito verificador, sin
/// puntos ni guiones). Acepta cadenas de 7 u 8 dígitos:
/// - 7 dígitos: los primeros 6 son el cuerpo y el 7mo es el verificador.
/// - 8 dígitos: los primeros 7 son el cuerpo y el 8vo es el verificador.
bool isValidUruguayanCi(String rawCi) {
  if (!_kFullCiPattern.hasMatch(rawCi)) return false;

  final body = rawCi.substring(0, rawCi.length - 1);
  final verifier = int.parse(rawCi.substring(rawCi.length - 1));

  return calculateUruguayanCiVerifierDigit(body) == verifier;
}
