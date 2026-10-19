import 'package:flutter/services.dart';

/// Reglas de los campos de teléfono. El contrato no define el formato del
/// teléfono: estas reglas son una decisión del cliente, pensada para ayudar a
/// quien escribe (la regla definitiva es del servidor).
///
/// Se aceptan dígitos, espacio, `+`, `-` y paréntesis, y el teléfono tiene que
/// tener entre [kPhoneMinDigits] y [kPhoneMaxDigits] dígitos, contando solo los
/// dígitos. 8 es una línea fija uruguaya sin prefijo; 15 es el máximo
/// internacional (E.164).
const int kPhoneMinDigits = 8;
const int kPhoneMaxDigits = 15;

const String kInvalidPhoneMessage =
    'El teléfono tiene que tener entre $kPhoneMinDigits y $kPhoneMaxDigits '
    'dígitos.';

/// Filtro de lo que se puede escribir o pegar en un campo de teléfono.
final List<TextInputFormatter> kPhoneInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9 +\-()]')),
];

/// Valida un teléfono opcional: vacío vale; si no, tiene que tener entre
/// [kPhoneMinDigits] y [kPhoneMaxDigits] dígitos.
String? validateOptionalPhone(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  final digits = text.replaceAll(RegExp(r'\D'), '').length;
  if (digits < kPhoneMinDigits || digits > kPhoneMaxDigits) {
    return kInvalidPhoneMessage;
  }
  return null;
}
